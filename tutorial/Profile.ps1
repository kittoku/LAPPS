Import-Module -Name C:\WHERE_LAPPS_EXISTS\LAPPS.psm1

$Env:LAPPS_OPENSSL = 'C:\hoge\LibreSSL\openssl.exe'
$Env:LAPPS_SQLITE = 'C:\hoge\sqlite3.exe'
$Env:LAPPS_PUBLIC_KEY_DATABASE = 'C:\hoge\key.db'
$Env:LAPPS_LINK_DATABASE = 'C:\hoge\link.db'
$Env:LAPPS_SELF = 'Alice_Smith'
$Env:LAPPS_PRIVATE_KEY = 'C:\hoge\alice.pem'
