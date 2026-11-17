import 'package:shared_preferences/shared_preferences.dart';

/// A partner invite sent as a link: `https://<app>/?pair=<CODE>`.
///
/// The code is the inviter's existing pairing code. Opening the link stores
/// it until the recipient has signed up or signed in, and then the home
/// screen pairs them through `accept_pairing`. See
/// `supabase/migrations/20261115000001_pair_invite_links.sql`.
class PairInvite {
  static const pendingKey = 'pending_pair_invite_code';

  /// The code in canonical form, or null if [code] can't be one. Pairing
  /// codes are 8 characters from A–Z and 0–9; a little slack is allowed.
  static String? normalize(String? code) {
    final c = code?.trim().toUpperCase();
    if (c == null || !RegExp(r'^[A-Z0-9]{6,12}$').hasMatch(c)) return null;
    return c;
  }

  static Uri buildUrl(String appBaseUrl, String code) {
    final base = Uri.parse(appBaseUrl);
    return base.replace(path: '/', queryParameters: {'pair': code});
  }

  static String buildMessage({required Uri url, required String code}) =>
      "Let's share our to-dos on EvenHalf. Tap to pair with me: $url\n"
      '(Or enter my code $code in the app.)';

  /// Reads `?pair=<CODE>` from the launch URL (web) and keeps it until the
  /// user is signed in. Returns the code, if any.
  static Future<String?> capture(Uri launchUri) async {
    final code = normalize(launchUri.queryParameters['pair']);
    if (code == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingKey, code);
    return code;
  }

  static Future<String?> pending() async {
    final prefs = await SharedPreferences.getInstance();
    return normalize(prefs.getString(pendingKey));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingKey);
  }
}

/// What happened when a stored invite was used after sign-in.
class PairInviteOutcome {
  final bool paired;
  final String message;
  const PairInviteOutcome({required this.paired, required this.message});
}
