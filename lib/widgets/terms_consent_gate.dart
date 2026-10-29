import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/legal_urls.dart';
import '../utils/terms_consent.dart';

/// 初回描画後に利用規約の同意状況を確認し、未同意なら同意ダイアログを表示するラッパー
class TermsConsentGate extends StatefulWidget {
  final Widget child;

  const TermsConsentGate({super.key, required this.child});

  @override
  State<TermsConsentGate> createState() => _TermsConsentGateState();
}

class _TermsConsentGateState extends State<TermsConsentGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConsent());
  }

  Future<void> _checkConsent() async {
    int? accepted;
    try {
      final prefs = await SharedPreferences.getInstance();
      accepted = prefs.getInt(kAcceptedTermsVersionKey);
    } catch (_) {
      // 読込失敗時は安全側（未同意扱い）でダイアログを表示する
      accepted = null;
    }
    if (!mounted) return;
    if (!needsTermsConsent(accepted, kTermsVersion)) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TermsConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TermsConsentDialog extends StatefulWidget {
  const _TermsConsentDialog();

  @override
  State<_TermsConsentDialog> createState() => _TermsConsentDialogState();
}

class _TermsConsentDialogState extends State<_TermsConsentDialog> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _open(kTermsOfServiceUrl);
    _privacyTap = TapGestureRecognizer()..onTap = () => _open(kPrivacyPolicyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// 外部ブラウザでURLを開く。失敗時は汎用文言を表示する
  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ページを開けませんでした')),
      );
    }
  }

  Future<void> _accept() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kAcceptedTermsVersionKey, kTermsVersion);
    } catch (_) {
      // 保存失敗時も利用は継続できるようにし、次回起動時に再表示される
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('利用規約への同意'),
        content: SingleChildScrollView(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'ご利用の前に、'),
                TextSpan(text: '利用規約', style: linkStyle, recognizer: _termsTap),
                const TextSpan(text: 'と'),
                TextSpan(
                  text: 'プライバシーポリシー',
                  style: linkStyle,
                  recognizer: _privacyTap,
                ),
                const TextSpan(text: 'をご確認ください。\n\n同意いただける場合は「同意する」を押してください。'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('同意しない'),
          ),
          FilledButton(
            onPressed: _accept,
            child: const Text('同意する'),
          ),
        ],
      ),
    );
  }
}
