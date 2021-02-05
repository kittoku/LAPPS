# LAPPS: 簡易電子承認システム
LAPPSは[Linked Approval Protocol](https://github.com/kittoku/Linked-Approval-Protocol)をPowerShellで実装した簡易的な電子承認システムです．最低限な電子承認の機能を最小限のコストで実現することを目的として作成されました．

## できること
- ECDSA(secp256k1)を用いたファイルの承認
- SHA-256を用いたファイルの完全性の証明
- 承認行為の前後関係の証明

## できないこと
- 公開鍵基盤(PKI)を用いた公開鍵の保証  
LAPPSではハッシュや署名を<i>公開(Publish)</i>するという原始的な方法でそれらの改ざんを防止します．公開の手法はデータを会社の掲示板に書き込む，メーリングリストに流す，SNSで発信する，公正証書を作成する等が考えられます．

- タイムスタンプを用いた承認が行われた時刻の証明  
LAPPSでは承認が行われた時刻の情報をデータベースに記録しますが，本質的には記録された時刻と実際に承認が行われた時刻は無関係です．しかし，承認行為の署名を作成する際に直前に作成された署名を*からませる*ことで承認がどのような**順序**で行われたかを証明することができます．

- GUIによる操作やワークフローによる自動化  
現在のところLAPPSはCUIのみ提供しています．CUIに慣れない人が使用したり，より高度な機能を実現したりするためにはユーザー自身による抽象化や実装が必要になります．すみません．

- アクセス制御  
LAPPSではクライアントサーバシステムで提供されるような細やかなアクセス制限は実装されていません．故に悪意を持ったユーザーはデータベースに登録された署名や公開鍵を改ざんすることができます．ただし，改ざん前に公開鍵を公開していれば改ざんを検出することが可能であり，また，秘密鍵が流出しない限りなりすましは事実上不可能です．


## 依存関係
LAPPSの動作には以下のソフトウェアが必要です．すべてOSSとして公開されています．
- [PowerShell](https://github.com/PowerShell/PowerShell)  
動作確認はバージョン7.0(LTS)でのみ行っています．
- [OpenSSL](https://www.openssl.org)の実行可能なバイナリ
- [SQLite](https://www.sqlite.org)の実行可能なバイナリ

OpenSSLとSQLiteは[こちら](https://github.com/kittoku/LAPPS/releases/download/v0.0.0/external.zip)から再配布しています．OpenSSLについては互換性のある[LibreSSL](https://github.com/libressl-portable/portable)を私がビルドしたものを再配布しています．慎重な方はご自身でビルドしてください．  
  
また，LAPPSを使用する全員が書き込み権限を持つ共有ディレクトリが必要です．

## チュートリアル
1. [モジュールのインポート/データベースの生成/ユーザーの登録](tutorial/tutorial_prepare.ps1)
2. [ファイルの承認](tutorial/tutorial_approve.ps1)

## ライセンス
本モジュールはMITライセンスの下で公開されています．
