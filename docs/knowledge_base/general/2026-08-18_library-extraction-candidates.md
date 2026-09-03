**カテゴリ**: general　**元ファイル名**: investigation_library_extraction_candidates_2026-08-18.md

---

# 調査レポート：コードのライブラリ化に関する調査・方針（2026-08-18）

## 1. 概要（目的・背景）

マスター（プロジェクトオーナー）から「コードをライブラリ化したい」という要望があり、brainstormingによって意図を確認した。確認の結果、目的は将来的に他のFlutterプロジェクト（HKL-002 budget-app、HKL-004 timetable-app）とコードを共有することにあると判明した。ただし、HKL-002・HKL-004はいずれも現時点では企画段階（docsのみでコード未着手）であり、実装にFlutterを採用するかどうかも未定である。

この背景を踏まえ、今回は以下の方針で進めることに合意した。

- アプリ内モジュール分割（レイヤードアーキテクチャ化）は将来課題とし、今回は対象外とする。
- `packages/`配下への物理的なパッケージ分割（melosによるmonorepo化等）も今回は行わない。
- 今回のスコープは**設計書の作成のみ**とし、実装（コード変更）は一切行わない。

本レポートは、`lib/`配下の実装を実際に読んで調査した結果と、それを踏まえた切り出し方針・代替案の検討結果をまとめたものである。

## 2. 現状分析

`C:\Users\gothf\develop\HKL-001_shopping_list_app\lib\`配下の構成を実際に確認し、「アプリ固有で汎用化不可な実装」と「アプリのドメインに依存しない実装パターンとして汎用化候補になりうる実装」を切り分けた。

### 2.1 アプリ固有（汎用化不可）

| 対象 | 理由 |
|---|---|
| `lib/database/database_helper.dart` | `items`／`lists`／`favorites`／`categories`という買い物リスト固有のスキーマにCRUD実装が直結している。汎用DBヘルパーとして抽象化するには大規模な再設計が必要であり、今回は対象外とする |
| `lib/models/` | 買い物リストのドメインモデルそのもの |
| `lib/providers/` | 買い物リストのドメインロジックそのもの |
| `lib/screens/` | 買い物リストのUI・画面遷移そのもの |

### 2.2 汎用化候補（アプリのドメインに依存しない実装パターン）

現状のコードを確認した結果、以下の2ファイル・一部関数が、買い物リストというドメインに依存しない「実装パターン」として汎用化候補になりうることを確認した。

#### (1) `lib/widgets/ad_banner.dart` — AdMobアダプティブバナー広告の実装パターン

`AdBannerWidget`（`StatefulWidget`）は、`AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize()`を用いて画面幅に応じた可変幅のバナー広告サイズを取得し、`BannerAd`のロード・表示・破棄（`dispose()`でのリソース解放）までのライフサイクルを一貫して管理する実装になっている。この一連のパターン自体は買い物リストというドメインに依存しない。

現状は`adUnitId`がファイル冒頭の`_kBannerAdUnitId`という定数としてハードコードされている（`ad_banner.dart` 4行目）。この値を外部化し、コンストラクタ引数（例：`AdBannerWidget({required this.adUnitId})`）として受け取る形に変更すれば、広告ユニットIDだけをアプリごとに差し替えて他アプリへそのまま転用できる状態になると考えられる。

#### (2) `lib/services/backup_service.dart` — 一部関数のみが汎用化候補

`BackupService`クラス全体はスキーマ（`categories`／`lists`／`items`／`favorites`）に強く依存しており、クラス全体を汎用化することはできない。ただし、以下の2箇所は実装パターンとして汎用化候補になりうることを確認した。

- **`sanitizeFileName()`（14〜19行目）**：文字列をファイル名として安全な形へ変換する純粋関数。禁止文字（`/ \ : * ? " < > |`および制御文字）を`_`へ置換し、前後の空白・ドットを除去したうえで50文字に丸める処理であり、買い物リストのスキーマには一切依存しない。
- **`export()`（71〜85行目）・`saveToDevice()`（89〜100行目）のファイルI/O・共有シート連携パターン**：`export()`では一時ディレクトリ（`getTemporaryDirectory()`）にファイルを書き出し、`share_plus`の`Share.shareXFiles()`で共有シートへ渡したのち`finally`ブロックで一時ファイルを削除する、という「JSON文字列→一時ファイル→共有シート→後始末」の骨格が確認できる。`saveToDevice()`では`file_picker`の`FilePicker.platform.saveFile()`を用いて端末への直接保存（Android的にはSAF経由）を行っている。これらのI/Oパターン自体はスキーマに依存しない。

なお、`buildExportMap()`（22〜37行目）や`_buildFullBackupJson()`（40〜60行目）はJSONの中身（`categories`／`lists`／`items`／`favorites`）を組み立てる処理であり、スキーマに強く依存するため汎用化候補には含めない。

### 2.3 対比まとめ

| 区分 | 対象 | 汎用化の可否 |
|---|---|---|
| アプリ固有 | `database_helper.dart`／`models/`／`providers/`／`screens/` | 不可（スキーマ・ドメインロジックに直結） |
| 汎用化候補 | `ad_banner.dart`（`adUnitId`の外部化が前提） | 可 |
| 汎用化候補 | `backup_service.dart`内`sanitizeFileName()` | 可（既に純粋関数） |
| 汎用化候補 | `backup_service.dart`内`export()`／`saveToDevice()`のI/O骨格 | 可（JSON構築部分と分離すれば） |

## 3. 切り出し方針

### 3.1 トリガー条件

HKL-002（budget-app）またはHKL-004（timetable-app）のいずれかの技術スタックがFlutterに確定した時点で、実際の切り出し作業に着手する。現時点ではいずれも企画段階（docsのみでコード未着手）であり、Flutter採用が未確定であるため、**今回は着手しない**。

### 3.2 実現方法

切り出しの実現方法については、以下の2案のいずれを採るかを着手時点で改めて判断することとし、現時点では確定しない。

- 物理パッケージ化（`packages/`配下・melos等を用いたmonorepo構成）
- コピー転用（必要な実装を都度新プロジェクトへコピーし、個別にカスタマイズする方式）

### 3.3 対象範囲

「2.2 汎用化候補」で挙げた以下2ファイル・一部関数を対象とする。

- `lib/widgets/ad_banner.dart`（`adUnitId`の外部化を前提とした全体）
- `lib/services/backup_service.dart`内の`sanitizeFileName()`、および`export()`／`saveToDevice()`のファイルI/O・共有シート連携パターン部分

### 3.4 対象外

- `lib/database/database_helper.dart`
- `lib/models/`
- `lib/providers/`
- `lib/screens/`
- `lib/services/backup_service.dart`内、スキーマに依存する`buildExportMap()`・`_buildFullBackupJson()`等のJSON構築部分

### 3.5 保留事項

IAP・課金連携（`in_app_purchase`パッケージを利用する`lib/providers/purchase_provider.dart`等）については、今回の調査では詳細を確認していない。存在自体はディレクトリ構成から把握しているが、汎用化候補として扱えるかどうかは未調査であり、今回のスコープには含めない。将来、内容を確認したうえで本設計書へ追記可能な構成としておく。

## 4. 検討した代替案（不採用理由込み）

今回の方針を決定するにあたり、以下の代替案を検討したが、いずれも今回は採用しなかった。

1. **lib内レイヤー分け（UI／Logic／Dataの論理的整理、単一パッケージのまま）**
   却下理由：今回のスコープは設計書の作成のみであり、実装（コード変更）を伴う対応は対象外としたため。
2. **`packages/`配下への物理的パッケージ分割（melosによるmonorepo化）**
   却下理由：共有先（HKL-002／HKL-004）の技術スタックがFlutterに確定していない段階で、monorepo化という大掛かりな構成へ投資するのはリスクが高いと判断したため。
3. **今回採用：設計書のみを先行して作成し、コード変更は一切行わない**
   HKL-002・HKL-004の技術スタックが確定するまでは、汎用化候補の洗い出しと切り出し方針の合意にとどめ、実装への着手はトリガー条件（3.1参照）が満たされてから行うこととした。

## 5. まとめ

現時点での結論は以下のとおりである。

- 汎用化候補として`ad_banner.dart`（AdMobアダプティブバナー広告の実装パターン）と、`backup_service.dart`内の`sanitizeFileName()`および`export()`／`saveToDevice()`のファイルI/O骨格を特定した。
- 切り出しの実作業は、HKL-002またはHKL-004の技術スタックがFlutterに確定した時点で着手する。実現方法（物理パッケージ化かコピー転用か）はその時点で判断する。
- `database_helper.dart`・`models/`・`providers/`・`screens/`はアプリ固有のドメインロジックであり、対象外とする。
- IAP・課金連携は未調査のため保留とし、確認後に本設計書へ追記できるようにしておく。
- 今回はコード変更を伴わず、本設計書の作成のみで完結する。
