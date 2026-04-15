# ios_tetris

SwiftUI製のテトリスゲームアプリ。Canvas描画・Combineタイマー・UserDefaultsによるスコア保存を使用する。

## プロジェクト構成

```
ios_tetris/
├── ios_tetrisApp.swift              # エントリーポイント
├── Models/
│   ├── Tetromino.swift              # ピース定義（7種類・回転・色）/ Board定数 / Cell型
│   └── ScoreStore.swift             # スコア永続化（UserDefaults・Top10）
├── ViewModels/
│   └── GameViewModel.swift          # ゲームロジック全体（移動・回転・落下・ライン消去）
└── Views/
    ├── GameView.swift               # メイン画面・オーバーレイ・スワイプジェスチャー
    ├── BoardView.swift              # Canvas描画（ボード・ゴーストピース・アクティブピース）
    ├── NextPieceView.swift          # 次のピースプレビュー
    ├── ControlsView.swift           # 操作ボタン（左右・回転・ソフトドロップ・ハードドロップ）
    └── HighScoreView.swift          # ランキング画面（Top10）
```

## 主要な型・設計

- **GameViewModel**（ObservableObject）: ゲーム状態をすべて管理。`Combine.Timer` で落下タイマーを制御。
- **GameState** enum: `idle / playing / paused / gameOver` の4状態。
- **Tetromino**: `origin: Cell` を起点に `rotations` オフセットで実座標を計算する。
- **Board**: `columns = 10, rows = 20` の定数。`[[Color?]]` の二次元配列で盤面を表現。
- **ScoreStore**（ObservableObject・singleton）: `shared` インスタンスで View から直接参照する。

## 作業ルール

- コミットメッセージは日本語で書く。
- `git push` まで依頼された場合は確認なしで一連の流れを実行する。
- 機能追加は既存の SwiftUI + Combine パターンを踏襲する。新規ファイルは必要最小限にする。
- 署名は `DEVELOPMENT_TEAM: 6373UDNWPX` / `CODE_SIGN_STYLE: Automatic` を使う（`project.yml` で管理）。
- プロジェクトファイル変更後は `xcodegen generate` を実行して `ios_tetris.xcodeproj` を再生成する。
- SourceKit の型解決エラー（`Cannot find type 'Tetromino'` 等）はプロジェクト未生成時のインデクサノイズ。ビルドが通れば問題なし。

## よくある落とし穴

- `AppIcon` のアセットフォルダは `.appiconset`（`.appimageset` にすると "None of the input catalogs contained a matching app icon set" エラー）。
- `xcode-select` が CommandLineTools を向いているとビルド不可 → `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` で切り替える。
- タイマーのインターバルはレベルアップ後に `startTimer()` を再呼び出しして更新する（再呼び出しなしだと旧インターバルのまま）。
- ゴーストピースは `isValid()` で落下限界まで1行ずつ試行して求める。ボードの状態が変わるたびに `updateGhost()` を呼ぶ。
