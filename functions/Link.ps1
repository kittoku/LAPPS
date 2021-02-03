function New-LinkDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Path
    )

    $col1 = "num INTEGER PRIMARY KEY NOT NULL CHECK (num >= 0)"
    $col2 = "datetime TEXT NOT NULL"
    $col3 = "title TEXT NOT NULL"
    $col4 = "approver TEXT NOT NULL"
    $col5 = "hash TEXT NOT NULL"
    $col6 = "signature TEXT NOT NULL"

    "CREATE TABLE link (${col1}, ${col2}, ${col3}, ${col4}, ${col5}, ${col6})" |
        New-SqlCommand -Path $Path |
        Invoke-ExternalCommand |
        Out-Null

    $date_string = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    $initial_hash = '0' * 64
    $initial_signature = "${Env:LAPPS_OPENSSL} rand -hex 32" | Invoke-ExternalCommand | ForEach-Object { $_.ToUpper() }

    "INSERT INTO link VALUES (0, '${date_string}', 'INITIALIZE', '_SYSTEM', '${initial_hash}', '${initial_signature}')" |
        New-SqlCommand -Path $Path |
        Invoke-ExternalCommand |
        Out-Null
}

function New-SaltedHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Index,
        [Parameter(Mandatory)][String]$DateTime,
        [Parameter(Mandatory)][String]$Title,
        [Parameter(Mandatory)][String]$Approver,
        [Parameter(Mandatory)][String]$File
    )

    $temp = New-TemporaryFile

    $Index + $DateTime + $Title + $Approver | Out-File -FilePath $temp -Encoding utf8 -NoNewline
    Get-Content -Path $File -AsByteStream | Add-Content -Path $temp -AsByteStream

    "${Env:LAPPS_OPENSSL} dgst -hex -sha256 ${temp}" | Invoke-ExternalCommand | Format-Hash | Write-Output

    Remove-Item $temp
}

function New-Signature {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Hash,
        [Parameter(Mandatory)][String]$LastSignature,
        [String]$Passphrase
    )

    $temp = New-TemporaryFile

    $concatenated = $Hash + $LastSignature | ConvertTo-Bytes

    [System.IO.File]::WriteAllBytes($temp, $concatenated)

    $command = "${Env:LAPPS_OPENSSL} dgst -hex -sha256 -sign ${Env:LAPPS_PRIVATE_KEY}"
    if ($Passphrase.Length -ne 0) {
        $command += " -passin pass:${Passphrase}"
    }
    $command += " ${temp}"

    $command | Invoke-ExternalCommand | Format-Hash | Write-Output

    Remove-Item $temp
}

function New-ConfirmResult {
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)][String]
        [ValidateSet('SUCCESS', 'FAILURE')]
        $Type,

        [String]$Reason
    )

    [PSCustomObject]@{
        RESULT = $Type
        REASON = $Reason
    } | Write-Output
}

function Confirm-Record {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)][PSCustomObject]$Record,

        [Parameter(Mandatory)]
        [ValidateSet('HASH', 'SIGNATURE', 'ALL')]
        [String]$Property,

        [String]$File,
        [String]$LastSignature
    )

    if ($Property -in @('HASH', 'ALL')) {
        $challenge = New-SaltedHash `
            -Index $Record.INDEX -DateTime $Record.DATETIME -Title $Record.TITLE `
            -Approver $Record.APPROVER -File $File

        if ($challenge -ne $Record.HASH) {
            New-ConfirmResult -Type FAILURE -Reason "HASH is not matched" | Write-Output
            return
        }
    }

    if ($Property -in @('SIGNATURE', 'ALL')) {
        $pub_pem = New-TemporaryFile
        $plain = New-TemporaryFile
        $challenge = New-TemporaryFile

        $key_record = Get-KeyRecord -Approver $Record.APPROVER
        if ($null -eq $key_record) {
            New-ConfirmResult -Type FAILURE -Reason "APPROVER's key is not registered" | Write-Output
            return
        }
        $key_record.KEY | Format-PublicPem | Out-File -FilePath $pub_pem -Encoding utf8

        $bytes = $Record.HASH + $LastSignature | ConvertTo-Bytes
        [System.IO.File]::WriteAllBytes($plain, $bytes)

        $bytes = $Record.SIGNATURE | ConvertTo-Bytes
        [System.IO.File]::WriteAllBytes($challenge, $bytes)


        $result = "${Env:LAPPS_OPENSSL} dgst -sha256 -verify ${pub_pem} -signature ${challenge} ${plain}"
            | Invoke-ExternalCommand

        Remove-Item $pub_pem, $plain, $challenge

        if ($result -eq 'Verification Failure') {
            New-ConfirmResult -Type FAILURE -Reason "Verifying SIGNATURE is failed" | Write-Output
            return
        }
    }

    New-ConfirmResult -Type SUCCESS | Write-Output
}

function Approve-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$File,

        [String]$Title,
        [String]$DateTime,
        [Int]$WaitTime
    )

    $key_record = Get-KeyRecord
    if ($key_record.STATUS -eq 'INVALID') {
        throw "Current approver(ENV:LAPPS_SELF)'s status is INVALID"
    }

    if (Test-EncryptedPem -Path $Env:LAPPS_PRIVATE_KEY) {
        $passphrase = Read-Host -Prompt "Enter passphrase" -AsSecureString |
            ConvertFrom-SecureString -AsPlainText
    } else {
        $passphrase = ''
    }

    if ($Title.Length -eq 0) {
        $Title = Split-Path -Path $File -Leaf
    }

    $start_time = Get-Date
    if ($DateTime.Length -eq 0) {
        $set_time = $start_time
    } else {
        $set_time = [System.DateTime]::Parse($DateTime)
    }

    $DateTime = $set_time.ToString('yyyy-MM-ddTHH:mm:ssK')


    $lock = $Env:LAPPS_LINK_DATABASE + '.lock' | New-Lock -WaitTime $WaitTime

    $last_record = Get-LastLinkRecord

    $index = [Int32]($last_record.INDEX) + 1

    $hash = New-SaltedHash -Index $index -DateTime $DateTime -Title $Title -Approver $Env:LAPPS_SELF -File $File

    $signature = New-Signature -Hash $hash -LastSignature $last_record.SIGNATURE -Passphrase $passphrase


    $candidate = [PSCustomObject]@{
        INDEX = $array[0]
        DATETIME = $array[1]
        TITLE = $array[2]
        APPROVER = $array[3]
        HASH = $array[4]
        SIGNATURE = $array[5]
    }

    $result = Confirm-Record -Record $candidate -Property SIGNATURE -LastSignature $last_record.SIGNATURE

    if ($result.RESULT -ne 'SUCESS') {
        throw "The private key seems to be inconsistent with its public key"
    }


    "INSERT INTO link VALUES ($index, '${DateTime}', '${Title}', '${Env:LAPPS_SELF}', '${hash}', '${signature}')" |
        New-SqlCommand -Path $Env:LAPPS_LINK_DATABASE |
        Invoke-ExternalCommand |
        Out-Null

    $lock.Close()
}

function Get-LinkRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Index
    )

    "SELECT num, datetime, title, approver, hash, signature FROM link WHERE num = ${Index} LIMIT 1" |
        New-SqlCommand -Path $Env:LAPPS_LINK_DATABASE |
        Invoke-ExternalCommand |
        Split-LinkRecord |
        Write-Output
}

function Get-LastLinkRecord {
    [CmdletBinding()]
    param ()

    "SELECT num, datetime, title, approver, hash, signature FROM link ORDER BY num DESC LIMIT 1" |
        New-SqlCommand -Path $Env:LAPPS_LINK_DATABASE |
        Invoke-ExternalCommand |
        Split-LinkRecord |
        Write-Output
}

function Get-AllLinkRecord {
    [CmdletBinding()]
    param ()

    "SELECT num, datetime, title, approver, hash, signature FROM link" |
        New-SqlCommand -Path $Env:LAPPS_LINK_DATABASE |
        Invoke-ExternalCommand |
        Split-LinkRecord |
        Write-Output
}

function Split-LinkRecord {
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
            INDEX = $array[0]
            DATETIME = $array[1]
            TITLE = $array[2]
            APPROVER = $array[3]
            HASH = $array[4]
            SIGNATURE = $array[5]
        } | Write-Output
    }
}
