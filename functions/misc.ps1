function  New-SqlCommand {
    [OutputType([String])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$InputObject,
        [Parameter(Mandatory)][String]$Path
    )

    process {
        $InputObject = '"' + $InputObject + ';"'

        Write-Output "${Env:LAPPS_SQLITE} ${Path} ${InputObject}"
    }
}

function Invoke-ExternalCommand {
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$InputObject
    )

    process {
        $temp = New-TemporaryFile
        $InputObject += " 2>${temp}"

        $std_out = Invoke-Expression $InputObject
        $std_err = Get-Content -Path $temp | Where-Object { $_ -notmatch '^WARNING' } | Join-String
        Remove-Item $temp

        if ($std_err.Length -ne 0) {
            throw $std_err
        }

        $std_out | Write-Output
    }
}

function Test-EncryptedPem {
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$Path
    )

    process {
        $header = Get-Content $Path | Select-Object -Index 0

        $header -eq '-----BEGIN ENCRYPTED PRIVATE KEY-----' | Write-Output
    }
}

function Format-PublicPem {
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$InputObject
    )

    process {
        Write-Output '-----BEGIN PUBLIC KEY-----'

        $full_rows_count = $InputObject.Length -shr 6
        $left_chars_count = $InputObject.Length -band 63

        $num = 0
        for ($i = 0; $i -lt $full_rows_count; $i ++) {
            Write-Output $InputObject.Substring($num, 64)

            $num += 64
        }

        if ($left_chars_count -ne 0) {
            Write-Output $InputObject.Substring($num)
        }

        Write-Output '-----END PUBLIC KEY-----'
    }
}

function ConvertTo-Bytes {
    [OutputType([Byte[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$InputObject
    )

    process {
        $length = $InputObject.Length -shr 1

        $array = [System.Array]::CreateInstance([Byte], $length)

        0..($length - 1) |
        ForEach-Object {
            $array[$_] = [System.Convert]::ToByte($InputObject.Substring(2 * $_, 2), 16)
        }

        Write-Output (,$array)
    }
}

function Format-Hash {
    [OutputType([String])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$InputObject
    )

    process {
        $split = $InputObject |
        ForEach-Object { $_.Split(' ') } |
        Select-Object -Last 1

        $split.ToUpper() | Write-Output
    }
}

function New-Lock {
    [OutputType([System.IO.FileStream])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String]$Path,
        [ValidateRange(0, [Int]::MaxValue)][Int]$WaitTime
    )

    process {
        $is_locked = $false

        while ($true) {
            try {
                $lock = [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write)
                $is_locked = $true
            } catch [System.IO.IOException] {
                Start-Sleep -Seconds 1
            }

            if ($is_locked) {
                break
            }

            $elapsed = (Get-Date) - $start_time
            if ($elapsed.TotalSeconds -gt $WaitTime) {
                throw "Cannot lock the database"
            }
        }

        Write-Output $lock
    }
}
