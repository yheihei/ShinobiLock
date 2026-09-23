# カルマロック App Store公開・広告配信の記録

2026年9月16日9:04 JSTに1.0.0（ビルド13）がApp Reviewを通過し、自動公開されました。日本の[App Storeページ](https://apps.apple.com/jp/app/id6811883726)で無料配信を確認済みです。App Store Connectは「配信準備完了」で、ビルド13が選択されています。Family Controlsについての指摘は、提出済みIPAの検証結果を返信した後、ビルドを差し替えずに解消しました。経緯は[App Reviewの記録](app-review-2026-09-15.md)にあります。

9月17日11:41 JSTに、カルマのセリフ4種類を追加した1.0.1（ビルド14）を審査へ提出しました。[提出詳細](https://appstoreconnect.apple.com/apps/6811883726/distribution/reviewsubmissions/details/ef49199b-835b-4046-95b4-c809f0c5bacd)は「審査待ち」です。承認後に全ユーザーへ自動公開する設定で、現時点の公開版は1.0.0（13）です。

AdMobは9月17日にアプリ審査も承認されました。Googleの承認メールと、管理画面の「確認済み」「準備完了」を確認済みで、広告を配信できる状態です。同日朝、ユーザーから実機で広告が表示されたとの報告がありました。報酬処理や再ロックの確認は、この報告には含まれていません。

## 登録済みのサービス

| 項目 | 値・状態 |
| --- | --- |
| App Store Connect | Apple ID `6811883726`。公開版1.0.0（13）は「配信準備完了」。更新版1.0.1（14）は9月17日11:41に提出し「審査待ち」、承認後に自動公開 |
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
| App Storeプライバシー | SDKを含む7種類を申告。ユーザーが最終公開を実施し、管理画面の「公開済み」を確認 |
| AdMob App ID | `ca-app-pub-8902711511453943~5407058668` |
| リワード広告ユニット | `ca-app-pub-8902711511453943/9569277919` |
| 広告ユニット名・報酬 | カルマロック_リワード、1 操作の実行 |
| AdMobアカウント | 承認済み。9月15日1:12 JSTのGoogle承認メールを確認 |
| AdMobアプリ | App Store ID `6811883726`を紐付け済み。9月17日にアプリの確認は「確認済み」、承認状況は「準備完了」。Googleのアプリ承認メールも確認 |
| Family Controls配布権限 | 9月14日20:35のApple承認メールをGmailで確認。本体と3拡張のDistribution権限を有効化・保存 |
| UMP欧州向けメッセージ | 英語・日本語で公開済み。「同意しない」を表示 |

サポート: https://yheihei.github.io/karma-lock/

プライバシーポリシー: https://yheihei.github.io/karma-lock/privacy.html

app-ads.txt: https://yheihei.github.io/app-ads.txt

上記はGitHub Pagesで公開済み。配信リポジトリは `yheihei/yheihei.github.io`、公開コミットは `643fa16`（9月16日にApp Storeのダウンロードリンクを追加）。ビルド13の待機手順は `47974dd` で反映しました。ソースは本リポジトリの `docs/site/`。ストアのプライバシーポリシーURLも保存済みです。

## 1.0.1（ビルド14）：カルマのセリフ追加

- 広告視聴前のセリフを4種類追加し、合計30種類にしました。1.0.0（13）の同梱JSONとの差分は、この4種類のみです。通常サイズでの表示確認は[カルマの間の記録](karma-room.md#2026年9月17日作者の広告収益に触れるセリフ4種)にあります。
- ストアの更新情報に、セリフを4種類追加したことを記載しました。既存の掲載文・スクリーンショット・審査メモを引き継ぎ、メモ冒頭にセリフ追加の説明を加えました。
- Coreの30テストが成功。Releaseアーカイブ・App Store用エクスポートが成功し、本体と3拡張すべてが1.0.1（14）であることを確認しました。
- 実際にアップロードしたIPAの本体と3拡張について、署名と配布プロファイルのFamily Controls権限、`get-task-allow = false`、strict署名検証を確認しました。本番AdMob IDと追加4種類を含むJSONも一致しています。IPAのMD5はContentDeliveryログと照合済みです。
- 11:36:27にアップロード成功。GoogleMobileAdsとUserMessagingPlatformのdSYM不足の警告は出ていますが、アップロードは成功し、Apple側のビルド処理も完了しました。
- 暗号化区分は既存版と同じ「上記のアルゴリズムのどれでもない」で保存。ビルド14を選択し、11:41に「1項目が提出されました」を確認しました。提出IDは `ef49199b-835b-4046-95b4-c809f0c5bacd`。提出詳細でも1.0.1（14）と「審査待ち」を確認しました。
- 公開設定は「このバージョンを自動でリリースする」「すべてのユーザ向けに今すぐアップデートをリリース」。審査承認・公開の完了はまだ確認していません。

証拠は `build/app-store-archive-14.log`、`build/app-store-core-checks-14.log`、`build/app-store-export-14.log`、`build/app-store-upload-14.log`、`build/app-review-1.0.1-14/uploaded-signature-evidence.json` にあります。アップロードしたIPAは `build/app-review-1.0.1-14/ShinobiLock-build14-uploaded.ipa`、アーカイブは `build/KarmaLock-1.0.1-14.xcarchive` です。既存のビルドキャッシュを再利用し、新しいシミュレータは作成していません。

## 9月16日の公開確認とAdMob対応

- 9:01 JST、Appleから審査続行の返信。9:04に審査完了、9:06に配布承認メールを受信しました。
- App Store Connectの自動公開設定、1.0.0（13）、「配信準備完了」を確認しました。公開ページのアプリ名、無料価格、3枚のスクリーンショット、10秒待機の説明、プライバシー表示、デベロッパWebサイトのリンクも確認しました。
- AdMobのストア検索は、IDのみでは結果が出ませんでした。日本のURL `https://apps.apple.com/jp/app/id6811883726` では「カルマロック」「Yohei Kokubo」が見つかり、選択・保存に成功しました。アプリ設定にもストアIDが表示されています。
- app-ads.txtの確認では「お客様の詳細情報が AdMob アカウントの情報と一致しません」と表示されました。管理画面の指定値と公開ファイルは完全一致しています。HTTP/HTTPSとも最終的にHTTP 200、`text/plain`で返り、BOMもありません。robots.txtは404で、クロールを拒否する記述はありません。
- 公開中のApp StoreページのデベロッパWebサイトは `https://yheihei.github.io/karma-lock/` で、app-ads.txtはそのホストのルートにあります。「アップデートを確認」を実行しましたが、現時点では確認を通過していません。app-ads.txt一覧には取得URL・前回クロールのデータがまだ表示されていません。
- ポリシーセンターは「現在、問題はありません」。欧州向け同意メッセージは「1件有効」です。
- サポートページにApp Storeのダウンロードリンクを追加しました。GitHub Pagesのビルド完了を確認しています。
- 公開ページでダウンロードリンクの表示とリンク先を確認しました。READMEとApp Reviewの記録も公開済みの状態に更新しました。
- iPhoneミラーリングは初期設定前で、実機の操作確認には使えませんでした。セットアップは変更していません。

公開ファイルの誤りは確認できていません。公開直後のストア情報やGoogle側の取得結果の反映待ちの可能性がありますが、原因は未確定です。[Googleの案内](https://support.google.com/admob/answer/9776740?hl=ja)では、app-ads.txtのクロールと検証に最大24時間かかる場合があります。確認が完了した後も、[アプリの準備状況の審査](https://support.google.com/admob/answer/10564477?hl=ja)が別途必要です。

## 9月17日のアプリ確認完了と広告審査開始

- ユーザーから、今朝カルマロックを開いたところ広告が表示されたとの報告がありました。広告の表示を確認したという報告であり、テスト広告かどうかや報酬処理・再ロックの確認は含まれていません。
- 管理画面は当初「未確認」「要審査」でした。「Verify app」を再実行すると「カルマロック（iOS）の確認が完了しました」と表示されました。公開ファイルやストア情報の変更は行っていません。
- 「完了」を押した後、アプリ設定で「確認済み」「準備中」を確認しました。Googleは、審査は通常2〜3日で完了し、審査完了までは広告配信を制限すると案内しています。
- この確認時点で、新しいAdMob承認通知はGmailにありませんでした。画面上は広告審査の開始まで確認できており、最終承認はまだです。

## 9月17日の広告審査承認

- 8:59 JSTにGoogle AdMobから「アプリが承認されました: カルマロック（iOS）」を受信しました。本文でアプリ審査の完了と広告配信が可能になったことを確認しました。
- AdMobのアプリ設定でも、カルマロックの「アプリの確認」が「確認済み」、「承認状況」が「準備完了」になっています。
- App Store公開とAdMobの広告審査は完了しました。毎日10:00（Asia/Tokyo）の自動フォロー（ID `admob`）は停止し、状態が `PAUSED` になったことを確認しました。

### 残っている実機確認

実機で表示された広告が本番広告であることと、視聴完了後の報酬処理・5分後の再ロックを確認する。ビルド13の広告なし10秒待機とキャンセルも実機確認の記録が残っていない。

## ビルドと検証

- 1.0.0（10）のDebugビルドが成功し、接続中のiPhone 12 miniへのインストールと起動に成功。
- コアテストはXCTest 11件とSwift Testing 14件、計25件が合格。
- Releaseアーカイブ `build/KarmaLock-1.0.0-10.xcarchive` が成功。本番広告ID、50件のSKAdNetwork ID、本体と3拡張を確認。
- 承認前のApp Store向け書き出しは、4つの配布プロファイルにFamily Controls権限がないため失敗（`build/app-store-export.log`）。承認後に本体と3拡張のDistribution権限を有効化し、ビルド11の書き出しが成功した（`build/app-store-export-11.log`）。IPA内の4プロファイルと署名で `com.apple.developer.family-controls=true`、デバッグ不可、App Store配布用であることを検証した。
- DebugではGoogleの公式テスト広告ユニットを使い、本番広告への自己インプレッションを避けます。本番のAdMob App IDを使うため、UMPはDebugでも動作します。
- ビルド10の実機で、広告中断ではロック継続、視聴完了で対象アプリだけ解除、本体終了後の5分再ロックについてユーザーが全項目成功と確認。診断ログでも21:15:21の解除開始に対し、21:20:22に終了前の警告通知を確認した（約301秒）。本体を21:26:51に再起動して取得した時点では一時解除状態なし、対象7アプリがロック対象に戻っていた。証跡は `build/release-device-probe-after-reopen.json`。
- ビルド11では広告の最大コンテンツレーティングを一般向け（G）に制限。Releaseアーカイブ成功。ビルド10からUI・解除処理は変更していない。
- ビルド11のDebug実機ビルドも成功。21:42にiPhoneへの更新インストール、21:46に起動成功。ログは `build/device-build-11.log`、`build/device-install-11.log`、`build/device-launch-11.log`。
- ビルド11のアップロードは、3拡張の `CFBundleDisplayName` 不足（90360）でAppleの検証が失敗。各拡張と生成スクリプトに表示名を追加し、ビルド12へ更新した。アプリの動作処理は変更していない。`build/KarmaLock-1.0.0-12.xcarchive` の作成が成功し、本体と3拡張の表示名・ビルド番号を確認した。
- ビルド12は22:15:56にApp Store Connectへのアップロード成功。ログは `build/app-store-upload-12.log`。Google Mobile Ads / UMPのdSYMがSDKアーカイブに含まれない警告はあるが、Appleのパッケージ検証とアップロードは成功した。
- Apple側の処理完了後、暗号化の種類を「上記のアルゴリズムのどれでもない」として保存。独自の暗号化実装はなく、OSの暗号化を除く標準暗号ライブラリも追加していない。管理画面でビルド12の「提出準備完了」を確認した。
- ルールの休止・削除は9月13日の公式テスト広告による検証記録あり（`docs/rule-action-verification.md`）。ビルド12では、解除・休止・削除が同じ報酬処理を使い、読み込み失敗・中断時は変更処理を呼ばなかった。ビルド13では、取得・表示失敗時に10秒待機を提示し、本人の確認後に処理する。実機での待機・解除の目視確認はユーザー確認待ち。

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

## 9月14〜15日の提出履歴

ビルド12の選択・保存後、提出前チェックが通過。22:21に「審査へ提出」を実行し、「1項目が提出されました」「1.0.0 審査待ち」を確認しました。Gmail連携も再接続済みで、AppleとAdMobの関連通知を読めます。

当時の残作業はApp Review結果の確認と、公開後のAdMobへのストア紐付け・アプリ確認でした。9月16日の結果と現在の残作業は上記の通りです。

9月15日8:02の再提出では、登録済みのビルド12、掲載文、審査メモ、自動公開設定を維持し、提出前チェックが通過しました。SafariのApp Store Connectで提出完了を確認しました。提出IDは `694b750d-7c2a-4cd7-8fd7-4e9f6f76b3a7` です。

9月15日8:15、ユーザーの本番配信確認用に、最新ソースのRelease構成1.0.0（12）を開発署名でビルドし、接続中のiPhone 12 miniへインストール・起動しました。`build/device-release-12-check.log` の `BUILD SUCCEEDED`、`build/device-release-12-install.json`、`build/device-release-12-launch.json` を確認。本体と3拡張がビルド12で、本体の本番AdMob App ID・広告ユニットIDとFamily Controls署名権限を確認しました。このビルド12で、ユーザーが広告を取得できないエラーを確認しました。当時の仕様では解除・休止・削除を行えませんでした。Appleの規定4.10による広告方式の審査上の懸念も残り、広告の動作確認やFamily Controls権限の承認だけでApp Review通過を保証するものではありません。

## ビルド13：広告を表示できない場合の待機

9月15日の本番設定ビルド12で、ユーザーが広告取得時のエラー表示を確認しました。広告の取得・表示失敗時に、悲しそうなカルマとランダムなセリフを表示する待機を追加しました。セリフは `App/Resources/karma-lines.json` の `ad_unavailable` に10種類あり、直前のセリフ・表情を繰り返しません。既存の悲しい表情3枚を使っています。

- 10秒経過後に実行ボタンを有効化。本人が押すまで解除・休止・削除は行わない。
- 「やめておく」、画面終了、アプリを離れた場合は待機を破棄する。
- 広告の読み込み・表示失敗時だけ待機に移る。広告を本人が途中終了した場合は待機を提示しない。
- 同意情報の取得、SDK起動、広告取得には15秒のタイムアウトを設ける。同意フォームの本人操作中はタイムアウトを止める。
- 実行直前にも対象を確認し、同じ保存処理を使う。二重実行・待機終了後に届く広告の応答を拒否する。

ビルド13はReleaseビルド成功後、9月15日08:34に接続中のiPhone 12 miniへ更新し、08:34:57に起動成功を確認しました。本体と3拡張のビルド番号・Family Controls権限、本番広告IDを照合済み。Core 30件、広告制御13項目、保存処理37項目が合格しました。実機での待機・解除・再ロックの目視確認はユーザー確認待ちです。

### ビルド13の審査メモ

If an ad cannot be loaded or presented, the app shows Karma with a 10-second countdown. After the countdown, the user can explicitly confirm a 5-minute unlock, pause, or deletion. Nothing happens automatically. Cancelling or leaving the app keeps the existing lock and rules. Closing an ad before earning its reward does not offer this alternative. The same behavior is available to all users.

9月15日8:41:04にビルド13のアップロード成功（`build/app-store-upload-13.log`）。`build/KarmaLock-1.0.0-13.xcarchive` の本体と3拡張のビルド番号、本体の本番AdMob IDを確認しました。暗号化の種類はビルド12と同じ「上記のアルゴリズムのどれでもない」を保存済みです。

掲載文と審査メモは以下の内容に更新しました。`03-rewarded-unlock.jpg` をビルド13のiPhone 17 Pro Maxシミュレータで撮り直し、10秒待機の案内を含む画像へ差し替えました。1320×2868のJPEGで、PNGからの形式変換のみです。日本語の6.9インチ枠に3枚あり、6.5インチ枠への継承も確認しました。

8:51に再提出し、提出詳細でビルド13と「審査待ち」を確認しました。提出IDは `8f6c6123-e7c1-47b2-8292-a38b0ccdfef5`。旧ビルド12の提出 `694b750d-7c2a-4cd7-8fd7-4e9f6f76b3a7` は差し替えのため取り下げました。

サポートページはGitHub Pagesへ反映済み（`47974dd`）。公開URLの本文に10秒待機とキャンセルの案内があること、ルートの `app-ads.txt` がHTTP 200 / text/plainで正しいパブリッシャーIDを返すことを確認しました。

### AdMobの残処理（9月15日8:43確認）

- アカウント承認済み。アプリは「要審査」、ストア詳細は未登録、「アプリの確認」は「必須ではありません」の表示。
- ストアID `6811883726` で検索したが対象アプリは見つからず、紐付けは保存できなかった。App Store公開後の掲載情報の反映待ち。
- ポリシーセンターは「現在、問題はありません」。欧州向け同意メッセージは「1件有効」。通知にも、このアプリに対する追加の修正要求はなかった。
- 公開後にApp Storeを紐付け、AdMobのアプリ審査とapp-ads.txtの認識・確認を完了する。ファイルの公開だけでは、AdMob側のアプリ承認や広告配信の開始を意味しない。

## 掲載文

### プロモーション用テキスト

使いすぎを控えたいアプリを、決めた曜日と時間帯にロック。必要なときは広告視聴で対象アプリだけを5分間解除できます。

### 概要

使いすぎを控えたいアプリに、時間の区切りを。
カルマロックは、曜日と時間帯を決めてiPhoneのアプリをロックする、スクリーンタイム管理アプリです。

■ 曜日と時間帯でロック
勉強中、仕事中、寝る前など、アプリを開きたくない時間にルールを設定できます。複数のルールを組み合わせることもできます。

■ 必要なときだけ、5分間
ロック中に対象アプリを使いたいときは、リワード広告を最後まで視聴すると、そのアプリだけを5分間解除できます。時間が過ぎると再びロックされます。広告を途中で閉じた場合は解除されません。

■ 「カルマの間」でひと呼吸
ルールを休止・削除するときは、カルマとの会話と広告視聴を挟みます。勢いでルールを取り消す前に、決めたことを振り返る時間を作ります。

■ 選んだアプリとルールは端末内に保存
スクリーンタイムで選択したアプリの情報やルールを、広告配信のために送信することはありません。広告SDKが取り扱う情報については、プライバシーポリシーをご確認ください。

ご利用にはスクリーンタイムの許可が必要です。カテゴリから選ぶ場合も、保存されるのはその時点で選んだアプリです。後から追加したアプリはルールを編集して選択してください。Webサイトはロック対象外です。
広告の表示にはインターネット接続が必要です。広告を取得・表示できない場合は、カルマの画面で10秒待つと、一時解除・休止・削除の実行ボタンを押せます。自動では実行しません。「やめておく」を押したり、アプリを離れた場合は変更しません。広告を自分で途中終了した場合は、この待機には進みません。

### キーワード

スクリーンタイム,アプリ制限,集中,勉強,時間管理,スマホ依存,デジタルデトックス,習慣,使いすぎ防止

### App Reviewのメモ

This is a personal productivity app using Screen Time / Family Controls. No account or sign-in is required.

To test on a physical iPhone: grant Screen Time authorization, create a rule for the current weekday and time, and select an installed app. Open the selected app to see the shield. Follow the shield instructions to return to Karma Lock and request a temporary unlock. Completing a rewarded ad unlocks only the requested app for 5 minutes. Closing an ad early does not grant an unlock. Pausing or deleting a rule also uses the rewarded-ad flow.

If an ad cannot be loaded or presented, the app shows Karma with a 10-second countdown. After the countdown, the user can explicitly confirm a 5-minute unlock, pause, or deletion. Nothing happens automatically. Cancelling or leaving the app keeps the existing lock and rules. Closing an ad before earning its reward does not offer this alternative. The same behavior is available to all users.

Screen Time tokens and rule data remain on the device and are never supplied to the ad SDK. Google Mobile Ads requests non-personalized ads with publisher first-party ID disabled. UMP handles required consent and privacy options.

The app requires iOS 26.5 or later and a physical iPhone to verify shielding.
