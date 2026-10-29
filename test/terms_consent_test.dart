import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list_app/utils/legal_urls.dart';
import 'package:shopping_list_app/utils/terms_consent.dart';
import 'package:shopping_list_app/widgets/terms_consent_gate.dart';

Widget _app() => const MaterialApp(
      home: TermsConsentGate(child: Scaffold(body: Text('home'))),
    );

void main() {
  group('needsTermsConsent', () {
    test('未保存なら true', () {
      expect(needsTermsConsent(null, 1), isTrue);
    });
    test('同じバージョンなら false', () {
      expect(needsTermsConsent(1, 1), isFalse);
    });
    test('古いバージョンなら true', () {
      expect(needsTermsConsent(1, 2), isTrue);
    });
    test('新しいバージョンなら false', () {
      expect(needsTermsConsent(3, 2), isFalse);
    });
  });

  group('TermsConsentGate', () {
    testWidgets('未同意ならダイアログが表示される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('利用規約への同意'), findsOneWidget);
      expect(find.text('同意する'), findsOneWidget);
      expect(find.text('同意しない'), findsOneWidget);
    });

    testWidgets('同意済みならダイアログは表示されない', (tester) async {
      SharedPreferences.setMockInitialValues({
        kAcceptedTermsVersionKey: kTermsVersion,
      });
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('利用規約への同意'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('同意するでバージョンが保存されダイアログが閉じる', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('同意する'));
      await tester.pumpAndSettle();

      expect(find.text('利用規約への同意'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kAcceptedTermsVersionKey), kTermsVersion);
    });

    testWidgets('同意しないでSystemNavigator.popが呼ばれ保存されない', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意しない'));
      await tester.pumpAndSettle();

      expect(calls, contains('SystemNavigator.pop'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kAcceptedTermsVersionKey), isNull);
    });
  });
}
