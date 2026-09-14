# カルマロック App Store公開準備

2026年9月14日。初回は日本のみで公開する方針。公開・審査提出はまだ行っていません。

## 登録済みのサービス

| 項目 | 値・状態 |
| --- | --- |
| App Store Connect | アプリ作成済み、Apple ID `6811883726`、バージョン1.0.0「提出準備中」 |
| Bundle ID | `com.yhei.shinobilock` |
| SKU | `com.yhei.shinobilock` |
| アプリ名・言語・カテゴリ | カルマロック、日本語、仕事効率化 |
| 配信地域 | 日本のみ。配信状況「1つの国または地域」、日本「アプリのリリース時に配信可能」を確認 |
| サブタイトル | 曜日と時間でアプリの使いすぎを防ぐ |
| Apple更新契約 | ユーザーが同意。Appleの契約履歴で2026年9月14日の同意日を確認 |
| App Review連絡先 | ユーザーが入力・保存。掲載文を含め保存済み状態を確認 |
| 価格・端末 | 無料価格を登録。Mac・Vision Pro配信を無効化し保存済み |
| 年齢区分・配信権 | 9+で保存。広告・生活習慣関連あり、装備武器の描写は「まれ」。第三者コンテンツの利用権を設定・保存 |
| スクリーンショット | 日本語3枚を6.9インチ枠に登録。再読み込み後も3枚を確認。6.5インチ枠にも継承 |
| App Storeプライバシー | SDKを含む7種類を入力・保存済み。最終公開時の同意はユーザー確認待ち |
| AdMob App ID | `ca-app-pub-8902711511453943~5407058668` |
| リワード広告ユニット | `ca-app-pub-8902711511453943/9569277919` |
| 広告ユニット名・報酬 | カルマロック_リワード、1 操作の実行 |
| AdMobアカウント | 審査待ち |
| Family Controls配布権限 | 申請受付の完了画面を確認。Appleの審査待ち |
| UMP欧州向けメッセージ | 英語・日本語で公開済み。「同意しない」を表示 |

サポート: https://yheihei.github.io/karma-lock/

プライバシーポリシー: https://yheihei.github.io/karma-lock/privacy.html

app-ads.txt: https://yheihei.github.io/app-ads.txt

上記はGitHub Pagesで公開済み。配信リポジトリは `yheihei/yheihei.github.io`、公開コミットは `4835406`。ソースは本リポジトリの `docs/site/`。ストアのプライバシーポリシーURLも保存済みです。

## ビルドと検証

- 1.0.0（10）のDebugビルドが成功し、接続中のiPhone 12 miniへのインストールと起動に成功。
- コアテストはXCTest 11件とSwift Testing 14件、計25件が合格。
- Releaseアーカイブ `build/KarmaLock-1.0.0-10.xcarchive` が成功。本番広告ID、50件のSKAdNetwork ID、本体と3拡張を確認。
- App Store向け書き出しは失敗。4つの配布プロファイルすべてに `com.apple.developer.family-controls` が含まれていない。ログは `build/app-store-export.log`。
- DebugではGoogleの公式テスト広告ユニットを使い、本番広告への自己インプレッションを避けます。本番のAdMob App IDを使うため、UMPはDebugでも動作します。
- ビルド10の実機で、広告中断ではロック継続、視聴完了で対象アプリだけ解除、本体終了後の5分再ロックについてユーザーが全項目成功と確認。診断ログでも21:15:21の解除開始に対し、21:20:22に終了前の警告通知を確認した（約301秒）。本体を21:26:51に再起動して取得した時点では一時解除状態なし、対象7アプリがロック対象に戻っていた。証跡は `build/release-device-probe-after-reopen.json`。
- ビルド11では広告の最大コンテンツレーティングを一般向け（G）に制限。Releaseアーカイブ成功。ビルド10からUI・解除処理は変更していない。
- ビルド11のDebug実機ビルドも成功。21:42にiPhoneへの更新インストール、21:46に起動成功。ログは `build/device-build-11.log`、`build/device-install-11.log`、`build/device-launch-11.log`。
- ルールの休止・削除は9月13日の公式テスト広告による検証記録あり（`docs/rule-action-verification.md`）。実際の通信断・在庫切れは未検証。現行コードでは解除・休止・削除が同じ報酬処理を使い、読み込み失敗・中断時は変更処理を呼ばない。

## ストア素材と申告の根拠

スクリーンショットは `docs/app-store-screenshots/ja/` の3枚。iPhone 17 Pro Max / iOS 26.5シミュレータで、製品の初回案内を撮影した1320×2868のJPEGです。PNGからの形式変換のみで、画面内容は加工していません。シミュレータではScreen TimeのApp Groupを開けないため、ロックの確認には上記の実機結果を使います。

キャラクターはCryptoNinja #024のカルマをもとにした二次創作です。2026年9月14日に[公式ガイドライン](https://www.ninja-dao.com/guidelines)の商用二次創作・公式画像を参照したAI制作の条件を確認しました。利用素材の由来は `docs/karma-portraits/manifest.json` に記録しています。

プライバシーのデータ種別と関連付けは、アーカイブに含まれるGoogle Mobile Ads 13.9.0 / UMP 3.1.0のマニフェストを確認しました。[Googleの開示資料](https://developers.google.com/admob/ios/privacy/data-disclosure)と[Appleの定義](https://developer.apple.com/app-store/app-privacy-details/)も参照しています。

| 収集データ | 用途 | ユーザーへの関連付け | トラッキング |
| --- | --- | --- | --- |
| おおよその場所 | サードパーティ広告、分析、アプリ機能 | あり | なし |
| デバイスID | サードパーティ広告、分析 | あり | なし |
| 製品の操作 | サードパーティ広告、分析、アプリ機能 | あり | なし |
| 広告データ | サードパーティ広告、分析 | あり | なし |
| クラッシュデータ | 分析 | なし | なし |
| パフォーマンスデータ | サードパーティ広告、分析、アプリ機能 | なし | なし |
| その他の診断データ | サードパーティ広告、分析 | なし | なし |

Googleのマニフェストには任意機能を含むデバイスIDのトラッキング・デベロッパ広告の用途も含まれます。今回の申告は実際の構成に合わせ、IDFA許可を要求せず、非パーソナライズ広告を指定し、Publisher First-party IDを無効にする構成として回答しています。自社広告・マーケティングは行いません。UMPが扱う3種類には「アプリの機能」を含めました。設定を変更する場合は、申告・同意実装・ポリシーも再確認します。

## 残っている作業

1. 保存済みのプライバシー回答を最終公開する。Appleの公開確認には回答の正確性・適用法令への準拠・変更時の更新に関する同意文があるため、ユーザーに確認を依頼する。
2. Family Controls承認後、本体とShieldConfiguration、ShieldAction、DeviceActivityMonitorの配布権限を有効化し、配布プロファイルを更新して書き出す。
3. App Store Connectへアップロードし、ビルド処理と必要項目を確認して審査提出する。
4. AdMobアカウントの承認を確認する。21:50頃の管理画面でも「アカウントはまだ承認されていません」「確認中」を確認した。App Store公開後にストアURLをAdMobへ紐付け、app-ads.txtとアプリの準備状況の確認を完了する。実広告の配信はまだ確認できていない。

## 掲載文

### プロモーション用テキスト

使いすぎを控えたいアプリを、決めた曜日と時間帯にロック。必要なときは広告視聴で対象アプリだけを5分間解除できます。

### 概要

使いすぎを控えたいアプリに、時間の区切りを。
カルマロックは、曜日と時間帯を決めてiPhoneのアプリをロックする、スクリーンタイム管理アプリです。

■ 曜日と時間帯でロック
勉強中、仕事中、寝る前など、アプリを開きたくない時間にルールを設定できます。複数のルールを組み合わせることもできます。

■ 必要なときだけ、5分間
ロック中に対象アプリを使いたいときは、リワード広告を最後まで視聴すると、そのアプリだけを5分間解除できます。時間が過ぎると再びロックされます。広告を途中で閉じたり、表示できなかった場合は解除されません。

■ 「カルマの間」でひと呼吸
ルールを休止・削除するときは、カルマとの会話と広告視聴を挟みます。勢いでルールを取り消す前に、決めたことを振り返る時間を作ります。

■ 選んだアプリとルールは端末内に保存
スクリーンタイムで選択したアプリの情報やルールを、広告配信のために送信することはありません。広告SDKが取り扱う情報については、プライバシーポリシーをご確認ください。

ご利用にはスクリーンタイムの許可が必要です。カテゴリから選ぶ場合も、保存されるのはその時点で選んだアプリです。後から追加したアプリはルールを編集して選択してください。Webサイトはロック対象外です。
広告の表示にはインターネット接続が必要です。広告の在庫や通信状況によっては、一時解除・ルールの休止や削除を行えない場合があります。

### キーワード

スクリーンタイム,アプリ制限,集中,勉強,時間管理,スマホ依存,デジタルデトックス,習慣,使いすぎ防止

### App Reviewのメモ

This is a personal productivity app using Screen Time / Family Controls. No account or sign-in is required.

To test on a physical iPhone: grant Screen Time authorization, create a rule for the current weekday and time, and select an installed app. Open the selected app to see the shield. Follow the shield instructions to return to Karma Lock and request a temporary unlock. Completing a rewarded ad unlocks only the requested app for 5 minutes. Closing an ad early or an ad failure does not grant an unlock. Pausing or deleting a rule also uses the rewarded-ad flow.

Screen Time tokens and rule data remain on the device and are never supplied to the ad SDK. Google Mobile Ads requests non-personalized ads with publisher first-party ID disabled. UMP handles required consent and privacy options.

The app requires iOS 26.5 or later and a physical iPhone to verify shielding.
