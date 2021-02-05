# ファイルを承認するためには
# ・LAPPSモジュールがインポートされていること
# ・以下の環境変数が設定されていること
# の2点が必要です．

Import-Module -Name 'C:\TEST\LAPPS'

$Env:LAPPS_OPENSSL = 'C:\TEST\LibreSSL\openssl.exe' # OpenSSLバイナリの場所
$Env:LAPPS_SQLITE = 'C:\TEST\sqlite3.exe'           # SQLiteバイナリの場所
$Env:LAPPS_PUBLIC_KEY_DATABASE = 'C:\TEST\key.db'   # 公開鍵データベースの場所
$Env:LAPPS_LINK_DATABASE = 'C:\TEST\link.db'        # リンクデータベースの場所
$Env:LAPPS_SELF = 'Alice_Smith'                     # 自分のユーザー名
$Env:LAPPS_PRIVATE_KEY = 'C:\TEST\alice.pem'        # 自分の秘密鍵の場所


# 【チュートリアル用のディレクトリに移動】
#　環境変数が設定されているので通常運用時は特定のディレクトリへの移動は不要です．
Set-Location -Path 'C:\TEST\'


# 【チュートリアル用に適当なファイルを作成】
'abcde' | Out-File -FilePath 'no_dot.txt'
'abcde.' | Out-File -FilePath 'with_dot.txt'


# 【ファイルの承認】
# パラメータを指定しない場合はファイル名がタイトル，現在時刻が承認時刻として登録されます．
Approve-File -File '.\no_dot.txt'

# タイトルと時刻を指定してのファイルの承認も可能です．
# WaitTimeパラメータを他のユーザーのデータベースへの書き込みをn秒間待つことができます．
Approve-File -File '.\with_dot.txt' -Title 'Permission to go home' -DateTime '2000-01-01T09:00:00' -WaitTime 30


# 【承認記録の取得】
Get-LastLinkRecord # 一番最後に承認された記録の取得
Get-LinkRecord -Index 1 # 1番目に承認された記録の取得
Get-AllLinkRecord # リンクデータベースに登録されている全承認記録の取得


# 【承認記録の検証(ハッシュ)】
$last_record = Get-LastLinkRecord
Confirm-Record -Record $last_record -Property HASH -File '.\with_dot.txt' # 成功します
Confirm-Record -Record $last_record -Property HASH -File '.\no_dot.txt' # 1文字でもファイルの内容が違うと失敗します


#【承認記録の検証(署名)】
$first_record = Get-LinkRecord -Index 1
$modified_record = Get-LastLinkRecord
$modified_record.HASH += '00'

Confirm-Record -Record $last_record -Property SIGNATURE -LastSignature $first_record.SIGNATURE # 成功します
Confirm-Record -Record $modified_record -Property SIGNATURE -LastSignature $first_record.SIGNATURE # 1バイトでもハッシュが違うと失敗します
Confirm-Record -Record $last_record -Property SIGNATURE -LastSignature ($first_record.SIGNATURE + 'FF') # 1バイトでも直前の承認記録の署名が違うと失敗します

# $modified_recordの署名(SIGNATURE)を改ざんした場合ももちろん失敗しますが，文字列を追加しただけの場合は成功します.
# OpenSSLの仕様で署名の後ろの無意味なバイト列が無視されるためです．
# この仕様を悪用しても他のユーザーを偽って署名を捏造することは不可能です．


# 【承認記録の検証(ハッシュと署名の両方)】
# 上述の2パターンの検証はまとめて行うことができます．
# ハッシュと署名の両方で検証が失敗した場合はハッシュでの失敗が理由として結果が出力されます．
Confirm-Record -Record $last_record -Property ALL -File '.\with_dot.txt' -LastSignature $first_record.SIGNATURE
