function New-KeyDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Path
    )

    $col1 = "approver TEXT PRIMARY KEY NOT NULL"
    $col2 = "status TEXT NOT NULL CHECK (status IN ('VALID', 'INVALID'))"
    $col3 = "key TEXT UNIQUE NOT NULL"

    "CREATE TABLE keys (${col1}, ${col2}, ${col3})" |
        New-SqlCommand -Path $Path |
        Invoke-ExternalCommand |
        Out-Null
}

function Register-Approver {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Approver,
        [Parameter(Mandatory)][String]$Path,
        [Switch]$UsePass
    )

    # generate a private key
    $ssl_command = "${Env:LAPPS_OPENSSL} genpkey -out ${Path} -outform PEM -algorithm EC -pkeyopt ec_paramgen_curve:secp256k1 -pkeyopt ec_param_enc:named_curve"
    if ($UsePass) {
        $passphrase = Read-Host -Prompt "Enter passphrase" -AsSecureString |
            ConvertFrom-SecureString -AsPlainText

        $confirmation = Read-Host -Prompt "Re-enter passphrase to confirm" -AsSecureString |
            ConvertFrom-SecureString -AsPlainText

        if ($passphrase -ne $confirmation) {
            throw "Entered passphrases are not matched"
        }

        if ($passphrase.Length -eq 0) {
            throw "No characters were entered"
        }

        $ssl_command += " -pass pass:${passphrase} -aes-128-cbc"
    }

    $ssl_command | Invoke-ExternalCommand | Out-Null


    # generate a public key
    $ssl_command = "${Env:LAPPS_OPENSSL} pkey -inform PEM -outform PEM -in ${Path} -pubout"
    if ($UsePass) {
        $ssl_command += " -passin pass:${passphrase}"
    }

    $pub = $ssl_command | Invoke-ExternalCommand | Where-Object { $_ -notmatch  '^-' } | Join-String

    "INSERT INTO keys VALUES ('${Approver}', 'VALID', '${pub}')" |
        New-SqlCommand -Path $Env:LAPPS_PUBLIC_KEY_DATABASE |
        Invoke-ExternalCommand |
        Out-Null
}

function Unregister-Approver {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Approver
    )

    "DELETE FROM keys WHERE approver = '${Approver}'" |
        New-SqlCommand -Path $Env:LAPPS_PUBLIC_KEY_DATABASE |
        Invoke-ExternalCommand |
        Out-Null
}

function Edit-ApproverStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Approver,
        [Parameter(Mandatory)][ValidateSet('VALID', 'INVALID')][String]$Status
    )

    "UPDATE keys SET status = '${Status}' WHERE approver = '${Approver}'" |
        New-SqlCommand -Path $Env:LAPPS_PUBLIC_KEY_DATABASE |
        Invoke-ExternalCommand |
        Out-Null
}

function Get-KeyRecord {
    [CmdletBinding()]
    param (
        [String]$Approver
    )

    if ($Approver.Length -eq 0) {
        $Approver = $Env:LAPPS_SELF
    }

    "SELECT approver, status, key FROM keys WHERE approver = '${Approver}' LIMIT 1" |
        New-SqlCommand -Path $Env:LAPPS_PUBLIC_KEY_DATABASE |
        Invoke-ExternalCommand |
        Split-KeyRecord |
        Write-Output
}

function Get-AllKeyRecord {
    [CmdletBinding()]
    param ()

    "SELECT approver, status, key FROM keys" |
        New-SqlCommand -Path $Env:LAPPS_PUBLIC_KEY_DATABASE |
        Invoke-ExternalCommand |
        Split-KeyRecord |
        Write-Output
}

function Split-KeyRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [String]
        $InputObject
    )

    process {
        if ($InputObject.Length -eq 0) {
            return
        }

        $array = $InputObject.Split('|')

        [PSCustomObject]@{
            APPROVER = $array[0]
            STATUS = $array[1]
            KEY = $array[2]
        } | Write-Output
    }
}
