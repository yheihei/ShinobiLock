# カルマの間

「広告を見て5分間解除」を押すと、広告の読み込み前にカルマの間を表示する。添付デザイン `Shinobi Lock2.html` の 3a / 3b をもとに、既存の解除画面へ追加した。解除画面の文言と要求の再表示は[利用の勧誘をなくす方針](unlock-intent.md)に従う。

- 「やめておく」では `stayed` のセリフを1秒表示して解除画面を閉じる。ロックは維持し、忍びロックのホームへ戻る。VoiceOver使用中はセリフを読み上げ、「ロックを続ける」で閉じる。
- 「それでも広告を見て5分間解除する」で、既存の広告読み込み・表示へ進む。報酬確定時だけ、対象アプリを5分間解除する。
- 広告の失敗・途中終了は従来の解除画面に表示する。再試行時もカルマの間を通る。
- カルマの間には戻るボタンを置かず、スワイプによる画面の閉じ操作も無効にする。

## セリフと表情

`App/Resources/karma-lines.json` の `unlock_before_ad` が広告前の26種類、`stayed` が踏みとどまったときのセリフ。JSON内の文字列を編集してビルドすると反映される。改行は `\n` で指定する。

追加20種類は、解除する前に自分で決めた約束や使いたかった時間を思い出させるセリフ。少し後ろめたさを感じさせつつ、踏みとどまれると信じていることを短い言葉ににじませる。熱く励ましたり、人格を否定したりする口調は避ける。

2026-09-13にNINJAMCPの `get_character` と `search_lore` でカルマの設定を確認した。取得した設定には口調・性格の指定がないため、追加セリフのクールな口調と信頼の表現はアプリ用の創作。参照応答は `output/karma-dialogue-additions/ninjamcp-reference.json`、追加20種類の一覧は `output/karma-dialogue-additions/追加セリフ20種.md` に保存した。

表示ごとにセリフと表情を選ぶ。直前の選択は端末内に保存し、解除画面やアプリを開き直しても同じセリフ・表情が続かないようにする。初回の表情はクールな正面の薄笑い。セリフを1種類に減らした場合は、そのセリフを毎回表示する。

表情は `App/Assets.xcassets` にある次の13点を使う。5分解除・ルール休止・ルール削除のカルマの間で共通。

- `karma-sad-bust`: 寂しそうに目を伏せる
- `karma-disappointed-front`: 悲しそうにこちらを見る
- `karma-sad-lookaway`: 視線をそらす
- `karma-cool-smirk`: 正面・ニヒルな薄笑い
- `karma-cool-folded-arms`: 右斜め・腕組み
- `karma-cool-side-eye`: 左斜め・横目の皮肉
- `karma-cool-appraising`: 右横顔・顎に手
- `karma-cool-knowing`: 左横顔・含み笑い
- `karma-cool-questioning`: 俯瞰・片眉を上げる
- `karma-cool-unimpressed`: あおり・無言の視線
- `karma-cool-scarf`: 右後方・肩越しの薄笑い
- `karma-cool-looking-back`: 左後方・静かな振り返り
- `karma-cool-hand-on-hip`: 斜め下・腰に手

背景は `karma-realm-bg`。画像は `output/karma-unlock-assets/generated` からコピーしたもの。素材を更新するときは対応する画像セット内のPNGも差し替える。

追加10点は `output/karma-portraits-10/cool-v2/transparent` の1024px透過PNGを使用する。NINJAMCPの公式2D/3D画像と設定を参照し、内蔵画像生成で表情・アングルの差分を作った。クール・ニヒルな性格表現はアプリ用の創作。背景の市松模様を除去し、髪やマフラーが画面の四辺に触れない余白を設けた。

通常サイズの絵は280pt、小さい画面では220pt。アクセシビリティの拡大文字では絵を160ptに縮め、選択肢を下部に固定する。上部のセリフはスクロールして読める。

## 検証方法

`swift test` では、セリフと表情の連続重複防止、セリフを1種類にした場合、空のセリフの代替表示、同梱JSONと画像ファイルを確認する。解除条件と広告報酬の重複防止は既存のテストも実行する。

シミュレータは画面と操作の確認に使う。Screen Timeで別アプリが実際にロックされること、広告視聴後に5分間だけ解除されることは実機で確認する。

### 2026-09-13 の確認結果

- 実機向けビルド、シミュレータ向けビルドが成功。Coreの21テストが成功。
- iPhone SE相当の375pt幅、iPhone 17 Proの通常サイズで画面を確認。最長セリフはSEで3行になり、両方の選択肢まで収まる。
- 拡大文字の `accessibility-extra-large` で、下部に固定した両方の選択肢と、セリフ末尾までのスクロールを確認。
- 「やめておく」の返事表示とホームへの復帰、再訪での表情・セリフ変更、広告読み込みへの移行を確認。
- シミュレータではGoogleのテスト広告取得が失敗した。エラー表示を確認したあと、画面確認用の失敗状態でも再試行を検証。カルマの間に戻り、両方の選択肢が再び有効になる。
- 画面確認用アプリは `build/karma-preview` に分離し、Screen Timeの状態にサンプルデータを使用した。最長セリフと広告失敗の再現もこの確認用アプリだけで行った。実機のロックと広告視聴完了後の解除は今回未確認。
- 添付HTMLのブラウザ表示はファイルURLの制限で開けなかったため、HTML内の寸法・文言・素材を参照した。

スクリーンショットは `output/karma-room-verification`。`karma-room-se.png`、`karma-room-iphone17pro.png`、`karma-room-se-long-line.png`、`karma-room-large-text.png` を保存した。

### クールな立ち絵10点の追加確認

- 追加10点を1024×1024pxの透過PNGで登録。元の透過素材とアプリ内のPNGは全点ハッシュが一致する。
- Coreの23テストが成功。初回の薄笑い、直前の表情を繰り返さない選択、全13点の画像ファイルの存在を確認した。
- アプリ本体のiOSシミュレータ向けビルドが成功。
- iPhone SE第3世代 / iOS 26.5で、追加10点すべてを実際の `KarmaRoomView` に表示。髪とマフラーが欠けず、背景に市松模様が残らないことを目視確認した。
- 拡大文字の `accessibility3` では、正面の立ち絵と下部の両方の選択肢が表示されることを確認した。
- 表示確認は `build/karma-portraits-preview` の専用アプリで行った。表示する画像と文字サイズだけを固定し、アプリ本体と同じView・素材を使用する。実機のロックや広告視聴完了後の解除は、この追加確認の対象外。

追加素材の記録は `output/karma-portraits-10/cool-v2/validation.json`、画面一覧は同じフォルダ内の `qa/simulator-overview.png`。ビルドログは `build/karma-cool-integration-build.log`、テストログは `build/karma-cool-swift-test.log`。
