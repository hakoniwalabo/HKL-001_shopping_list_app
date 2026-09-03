**カテゴリ**: reusable_patterns　**由来**: lib/widgets/ad_banner.dart（HKL-001, 基準コミット 90d82d2）

---

# AdMobアダプティブバナー広告の実装パターン

## 1. パターンの説明

`AdBannerWidget`（`StatefulWidget`）は、`google_mobile_ads`パッケージの`AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize()`を用いて画面幅に応じた可変幅のアダプティブバナー広告サイズを取得し、`BannerAd`のロード・表示・破棄までのライフサイクルを一貫して管理するパターンである。

- `didChangeDependencies()`のタイミングで（`BuildContext`が使える状態になってから）広告のロードを開始する。`initState()`ではなくこのタイミングを使うのは、`MediaQuery.of(context)`で画面幅を取得するために`context`が必要なため。
- 画面幅（`MediaQuery.of(context).size.width`）を整数に丸め、それを引数に`getCurrentOrientationAnchoredAdaptiveBannerAdSize()`を呼び出すことで、端末幅に合わせた高さのバナーサイズを取得する。
- ロード成功時（`onAdLoaded`）は`setState()`で`_loaded`フラグを立てて再描画し、ロード失敗時（`onAdFailedToLoad`）は取得済みの`BannerAd`インスタンスを`dispose()`したうえで参照を破棄する。
- ウィジェット破棄時（`dispose()`）に保持している`BannerAd`を確実に`dispose()`し、リソースリークを防ぐ。
- `build()`では、ロードが完了しURLが存在するまでは`SizedBox.shrink()`（サイズゼロ）を返し、ロード完了後は取得したサイズちょうどの`SizedBox`に`AdWidget`を載せて表示する。

このロード・表示・破棄のライフサイクル管理パターン自体は、広告ユニットIDの値を除けばアプリのドメイン（買い物リストという業務内容）に依存しない。

## 2. HKL-001での現状

現状（`lib/widgets/ad_banner.dart`）は、広告ユニットIDがファイル冒頭の下記の定数としてハードコードされている。

```dart
const _kBannerAdUnitId = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
```

このIDはHKL-001アプリ専用にAdMobコンソールで発行されたものであり、他プロジェクトへそのまま転用することはできない。

## 3. 汎用化版

`adUnitId`をコンストラクタの必須引数として受け取る形に変更したもの。ロジック自体（アダプティブサイズ取得・ロード・dispose）は元の実装をそのまま踏襲しており、IDの外部化以外の変更は加えていない。

```dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 画面幅に応じたアダプティブバナー広告を表示する汎用ウィジェット。
/// 広告ユニットIDは呼び出し側（アプリごと）から渡す。
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key, required this.adUnitId});

  /// AdMobの広告ユニットID（例: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy'）
  final String adUnitId;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Context が使えるタイミングで画面幅を取得して読み込む
    if (_ad == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (adSize == null || !mounted) return;

    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
```

## 4. 利用方法

新プロジェクトでは、`pubspec.yaml`に`google_mobile_ads`パッケージを追加し、プロジェクトごとにAdMobコンソールで発行した広告ユニットIDをコンストラクタ引数として渡して使用する。

```dart
AdBannerWidget(
  adUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy', // 新プロジェクト用のID
)
```

なお、AndroidManifest.xml／Info.plistへのAdMobアプリID登録、`MobileAds.instance.initialize()`の呼び出しなど、`google_mobile_ads`パッケージ自体のセットアップ手順は本パターンの対象外であり、新プロジェクト側で別途必要になる。

## 5. 既知の制限

- `didChangeDependencies()`の再ロード条件が`_ad == null`のみであるため、ロード失敗時（`onAdFailedToLoad`）に`_ad`をnullへ戻す実装と組み合わさると、依存変更（画面回転等で`didChangeDependencies()`が再度呼ばれるたび）に再ロードが走り得る。連続してロードに失敗する環境（オフライン時等）では、依存変更のたびに広告リクエストが繰り返される点に留意すること。
- `adUnitId`はコンストラクタの単一引数であるため、iOS対応時はAndroid用・iOS用で異なる広告ユニットIDを呼び出し側（`Platform.isIOS`等での分岐）で使い分けて渡す必要がある。本パターン自体はプラットフォーム分岐のロジックを含まない。

## 6. 検証済みバージョン

本パターンはHKL-001（`pubspec.yaml`）の以下のバージョンで動作確認済み。

- `google_mobile_ads: ^5.2.0`
