Import-Module -Name C:\WHERE_LAPPS_EXISTS\LAPPS.psm1

$Env:LAPPS_OPENSSL = 'C:\TEST\LibreSSL\openssl.exe'
$Env:LAPPS_SQLITE = 'C:\TEST\sqlite3.exe'
$Env:LAPPS_PUBLIC_KEY_DATABASE = 'C:\TEST\key.db'
$Env:LAPPS_LINK_DATABASE = 'C:\TEST\link.db'
$Env:LAPPS_SELF = 'Alice_Smith'
$Env:LAPPS_PRIVATE_KEY = 'C:\TEST\alice.pem'
