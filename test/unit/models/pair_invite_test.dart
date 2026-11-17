import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:evenhalf/models/pair_invite.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('normalize', () {
    test('uppercases and trims a valid code', () {
      expect(PairInvite.normalize(' ab12cd34 '), 'AB12CD34');
    });

    test('rejects missing, short, long and non-alphanumeric codes', () {
      expect(PairInvite.normalize(null), isNull);
      expect(PairInvite.normalize('ABC'), isNull);
      expect(PairInvite.normalize('A' * 13), isNull);
      expect(PairInvite.normalize('AB12-CD34'), isNull);
      expect(PairInvite.normalize('<script>'), isNull);
    });
  });

  test('buildUrl puts the code in ?pair= at the app root', () {
    final url = PairInvite.buildUrl(
        'https://evenhalf.example.com/welcome/', 'AB12CD34');
    expect(url.toString(), 'https://evenhalf.example.com/?pair=AB12CD34');
  });

  test('buildMessage includes the link and the code as a fallback', () {
    final url = Uri.parse('https://x.test/?pair=AB12CD34');
    final message = PairInvite.buildMessage(url: url, code: 'AB12CD34');
    expect(message, contains('https://x.test/?pair=AB12CD34'));
    expect(message, contains('enter my code AB12CD34'));
  });

  group('capture / pending / clear', () {
    test('keeps a valid code from the launch URL until cleared', () async {
      final code =
          await PairInvite.capture(Uri.parse('https://x.test/?pair=ab12cd34'));
      expect(code, 'AB12CD34');
      expect(await PairInvite.pending(), 'AB12CD34');

      await PairInvite.clear();
      expect(await PairInvite.pending(), isNull);
    });

    test('ignores URLs without a valid code', () async {
      expect(await PairInvite.capture(Uri.parse('https://x.test/')), isNull);
      expect(await PairInvite.capture(Uri.parse('https://x.test/?pair=bad!')),
          isNull);
      expect(await PairInvite.pending(), isNull);
    });

    test('a later link without a code keeps the stored one', () async {
      await PairInvite.capture(Uri.parse('https://x.test/?pair=AB12CD34'));
      // e.g. the OAuth redirect back to /auth/callback
      await PairInvite.capture(Uri.parse('https://x.test/auth/callback'));
      expect(await PairInvite.pending(), 'AB12CD34');
    });
  });
}
