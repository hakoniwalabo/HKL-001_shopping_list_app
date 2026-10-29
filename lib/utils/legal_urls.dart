// 利用規約・プライバシーポリシーのURLと、利用規約のバージョン定数

/// 利用規約のURL
const String kTermsOfServiceUrl =
    'https://hakoniwalabo.github.io/shopping_list_app/terms_of_service.html';

/// プライバシーポリシーのURL
const String kPrivacyPolicyUrl =
    'https://hakoniwalabo.github.io/privacy_policy.html';

/// 現在の利用規約バージョン
/// 規約を改定して再同意が必要になったときは、この値を上げること
const int kTermsVersion = 1;

/// 同意済みバージョンを保存する SharedPreferences のキー
const String kAcceptedTermsVersionKey = 'accepted_terms_version';
