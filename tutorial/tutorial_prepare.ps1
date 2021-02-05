# 【チュートリアル用のディレクトリを作成し移動】
New-Item -Path 'C:\TEST\' -ItemType Directory
Set-Location -Path 'C:\TEST\'


# 【LAPPSをダウンロード】
git clone https://github.com/kittoku/LAPPS


# 【モジュールのインポート】
Import-Module -Name .\LAPPS

<#
現在のところ，LAPPSを使用するためにはPowerShell起動時に毎回モジュールのインポートをする必要があります．
コマンドをC:\Users\YourName\Documents\PowerShell\Profile.ps1に書き込むとPowerShell起動時に自動で実行されます．
LAPPSの動作にはいくつかの環境変数(後述)の設定が必要ですが，永続的に環境変数を設定できない場合は，それらもProfile.ps1に書き込むと便利です．
書き方はtutorial/Profile.ps1を参考にしてください．
#>


# 以下の操作ではOpenSSLとSQLiteの場所が環境変数で設定されている必要があります．
$Env:LAPPS_OPENSSL = 'C:\TEST\LibreSSL\openssl.exe'
$Env:LAPPS_SQLITE = 'C:\TEST\sqlite3.exe'


# 【公開鍵データベースの作成】
New-KeyDatabase -Path 'C:\TEST\key.db'


# 以下の操作では公開鍵データベースの場所が環境変数で設定されている必要があります．
$Env:LAPPS_PUBLIC_KEY_DATABASE = 'C:\TEST\key.db'


# 【公開鍵データベースにユーザーを登録する】
# Pathの場所に秘密鍵が生成されます．
# Approverには空白を使用しないことを強く推奨します．
Register-Approver -Approver 'Alice_Smith' -Path 'C:\TEST\alice.pem'
Register-Approver -Approver 'Bob' -Path 'C:\TEST\bob.pem'


# UsePassパラメータを付けるとパスフレーズを設定できます．
# 同じコンピューターを複数のユーザーで共有する場合は必ず設定すべきです．
Register-Approver -Approver 'Charlie' -Path 'C:\TEST\charlie.pem' -UsePass


# 以下の操作では自分のユーザー名と秘密鍵の場所が環境変数で設定されている必要があります．
$Env:LAPPS_SELF = 'Alice_Smith'
$Env:LAPPS_PRIVATE_KEY = 'C:\TEST\alice.pem'


# 【ユーザーの削除】
# ユーザーを間違って登録したときのみ使用してください．
# 削除されたユーザーの承認記録は検証不可能になります．
Unregister-Approver -Approver 'Bob'


# 【ユーザーの失効】
# 秘密鍵の流出の可能性があるときなどに，ユーザーが承認できないように設定します．
Edit-ApproverStatus -Approver 'Charlie' -Status 'INVALID'


# 【ユーザーデータ(名前/ステータス/公開鍵)の取得】
# ユーザーを指定しない場合は自分のデータが出力されます.
# Get-Get-AllKeyRecordを使うと全ユーザーデータを出力します．
Get-KeyRecord -Approver 'Charlie'


# 【公開鍵データベースに登録されている全データをCSVに出力する】
Get-AllKeyRecord | Export-Csv -Path 'C:\TEST\all_keys.csv' -Encoding utf8 -NoTypeInformation


# 【リンクデータベースの作成】
# 承認されるファイルのハッシュと承認者の署名がこのデータベースに登録されます．
New-LinkDatabase -Path 'C:\TEST\link.db'


# 公開鍵データベースの内容に変更があった場合はただちにその旨を公開すべきです．
