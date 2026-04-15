# ios_tetris

SwiftUI製のテトリスゲームアプリ。Canvas描画・Combineタイマー・UserDefaultsによるスコア保存を使用する。

## プロジェクト構成

```
ios_tetris/
├── ios_tetrisApp.swift
├── Models/
│   ├── Tetromino.swift       # ピース定義（7種類・回転・色）/ Board定数 / Cell型
│   ├── ScoreStore.swift      # スコア永続化（UserDefaults・Top10）
│   ├── BGMPlayer.swift       # コロベイニキをAVAudioEngineでサイン波合成・ループ再生
│   ├── SFXPlayer.swift       # ライン消去SE（バスキック＋アルペジオ＋4列時スイープ）
│   └── Haptics.swift         # UIImpactFeedbackGeneratorのラッパー
├── ViewModels/
│   └── GameViewModel.swift   # ゲームロジック全体
└── Views/
    ├── GameView.swift         # メイン画面・オーバーレイ・スワイプ・コンボ表示
    ├── BoardView.swift        # Canvas描画（ボード・ゴースト・フラッシュ・パーティクル）
    ├── NextPieceView.swift    # PiecePreviewView を定義（HOLD/NEXT共用）
    ├── ControlsView.swift     # 操作ボタン（DAS/ARR対応左右・回転・ドロップ・ホールド）
    └── HighScoreView.swift    # ランキング画面（Top10）
```

## 主要な型・設計

- **GameViewModel**（ObservableObject）: ゲーム状態をすべて管理。`Combine.Timer` で落下タイマーと触覚/SE呼び出しを制御。
- **GameState** enum: `idle / playing / paused / gameOver` の4状態。
- **Tetromino**: `origin: Cell` を起点に `rotations` オフセットで実座標を計算する。ホールド時は `Tetromino.spawn(type)` でrotation=0に戻す。
- **Board**: `columns = 10, rows = 20` の定数。`[[Color?]]` の二次元配列で盤面を表現。
- **ScoreStore**（ObservableObject・singleton）: `shared` インスタンスで View から直接参照。
- **Particle** struct: ライン消去時にブロック色のパーティクルをGameViewModelが生成・物理更新（重力・フェード）。

## 実装済み機能

| 機能 | 詳細 |
|---|---|
| ホールド | 1ピースにつき1回。`canHold` フラグで重複防止。スポーン時にリセット |
| DAS/ARR | 左右長押し150ms後から50ms間隔で自動連続移動（`DASButton`） |
| ロックディレイ | 着地後0.5秒の猶予。移動/回転でリセット（最大15回） |
| コンボ | 連続ライン消去で `(combo-1)×50×level` ボーナス。COMBO×N!表示 |
| フラッシュ＋パーティクル | 消去行を0.22秒白発光→ブロック色のパーティクルが飛散 |
| SE | `SFXPlayer`: バスキック＋アルペジオ。4列消去時は周波数スイープ追加 |
| BGM | `BGMPlayer`: コロベイニキ（テーマA+B）を144BPMでAVAudioEngineにより無限ループ |
| 触覚 | 移動=light / 回転=light0.6 / ホールド=medium0.5 / 着地=medium / ハードドロップ=heavy / ライン消去=heavy(数に応じ強度変化、4列=rigid) / ゲームオーバー=notificationError |
| スコア保存 | UserDefaultsにTop10を保存。`HighScoreView`でランキング表示 |
| アプリアイコン | `generate_icon.py`（Pillow）で生成。`AppIcon.appiconset/AppIcon.png` |

## ゲームロジックのフロー

```
timerTick()
  ├─ canFall() → true  → performMove(dRow:1) → cancelLockTimer()
  └─ canFall() → false → startLockTimer()
                             └─ 0.5秒後 → executeLock()
                                  ├─ 消去なし → Haptics.lock() → spawnNext()
                                  └─ 消去あり → フラッシュ(0.22s) → 消去 → startDropTimer() → spawnNext()
```

## 作業ルール

- コミットメッセージは日本語で書く。
- `git push` まで依頼された場合は確認なしで一連の流れを実行する。
- 機能追加は既存の SwiftUI + Combine パターンを踏襲する。新規ファイルは必要最小限にする。
- 署名は `DEVELOPMENT_TEAM: 6373UDNWPX` / `CODE_SIGN_STYLE: Automatic` を使う（`project.yml` で管理）。
- プロジェクトファイル変更後は `xcodegen generate` を実行して `ios_tetris.xcodeproj` を再生成する。
- SourceKit の型解決エラー（`Cannot find type 'Tetromino'` 等）はプロジェクト未生成時のインデクサノイズ。ビルドが通れば問題なし。
- `Haptics` は必ずメインスレッドから呼ぶ（GameViewModelのpublicメソッドはすべてメインスレッド前提）。

## よくある落とし穴

- `AppIcon` のアセットフォルダは `.appiconset`（`.appimageset` にすると "None of the input catalogs contained a matching app icon set" エラー）。
- `xcode-select` が CommandLineTools を向いているとビルド不可 → `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` で切り替える。
- `PiecePreviewView` は `piece: Tetromino?` を受け取る。`nil` のとき空枠を表示（HOLDが未使用の状態）。
- `PiecePreviewView` は `piece.type.rotations[piece.rotation]`（生オフセット）を使って中央揃えで描画。`piece.cells`（ボード座標）を使うとプレビュー枠外にはみ出る。
- ロックディレイ中にホールドすると `cancelLockTimer()` が呼ばれる。ホールド後は `lockResets = 0` でリセット。
- `BGMPlayer` の `stop()` はエンジン停止のみ。次の `play()` で再びループ先頭から始まる（noteIdxはリセットしない→途中から再生）。完全リセットが必要な場合は `loadSong` 相当の処理が必要。
- タイマーのインターバルはレベルアップ後に `startDropTimer()` を再呼び出しして更新する。
