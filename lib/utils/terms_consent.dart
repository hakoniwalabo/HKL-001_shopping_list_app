/// 利用規約への（再）同意が必要かを判定する純粋関数
/// 未保存、または保存済みバージョンが現在より古い場合に true
bool needsTermsConsent(int? acceptedVersion, int currentVersion) {
  return acceptedVersion == null || acceptedVersion < currentVersion;
}
