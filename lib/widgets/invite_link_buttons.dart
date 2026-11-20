import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/pair_invite.dart';
import 'send_task_sheet.dart' show SendChannel, sendUri;

/// The analytics name for each channel (`log_pair_invite_sent`).
String inviteChannelName(SendChannel channel) => switch (channel) {
      SendChannel.whatsApp => 'whatsapp',
      SendChannel.text => 'text',
      SendChannel.email => 'email',
      SendChannel.copy => 'copy',
    };

/// Sends a partner invite link (`/?pair=<CODE>`) by WhatsApp, text, email or
/// copy, from the user's own phone. The partner taps it, signs up, and is
/// paired automatically.
class InviteLinkButtons extends StatefulWidget {
  final String code;
  final String appBaseUrl;

  /// Called after each send, with the channel's analytics name.
  final void Function(String channel)? onSent;

  /// Opens a URI; injectable for tests.
  final Future<bool> Function(Uri uri)? launcher;

  const InviteLinkButtons({
    super.key,
    required this.code,
    required this.appBaseUrl,
    this.onSent,
    this.launcher,
  });

  @override
  State<InviteLinkButtons> createState() => _InviteLinkButtonsState();
}

class _InviteLinkButtonsState extends State<InviteLinkButtons> {
  String? _notice;
  String? _manualCopy;

  Future<bool> _launch(Uri uri) async {
    try {
      final launcher = widget.launcher;
      if (launcher != null) return await launcher(uri);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _send(SendChannel channel) async {
    final url = PairInvite.buildUrl(widget.appBaseUrl, widget.code);
    final message = PairInvite.buildMessage(url: url, code: widget.code);
    setState(() {
      _notice = null;
      _manualCopy = null;
    });

    // Open the app (or copy) straight away, while still inside the tap:
    // browsers block popups and clipboard writes after an await.
    final uri = sendUri(channel, message, subject: 'Pair with me on EvenHalf');
    if (uri == null) {
      await _copy(message, 'Invite link copied. Paste it to your partner.');
    } else if (!await _launch(uri)) {
      await _copy(
          message, "Couldn't open that app, so the invite was copied instead.");
    }
    widget.onSent?.call(inviteChannelName(channel));
  }

  Future<void> _copy(String message, String done) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) setState(() => _notice = done);
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = "Copying isn't allowed here. Select the invite below "
              'and copy it.';
          _manualCopy = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Send your partner a link. They tap it, sign up, and you're paired.",
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _button(SendChannel.whatsApp, Icons.chat, 'WhatsApp'),
            _button(SendChannel.text, Icons.sms_outlined, 'Text'),
            _button(SendChannel.email, Icons.email_outlined, 'Email'),
            _button(SendChannel.copy, Icons.link, 'Copy link'),
          ],
        ),
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Text(
            _notice!,
            key: const Key('invite_notice'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (_manualCopy != null) ...[
          const SizedBox(height: 8),
          SelectableText(_manualCopy!, key: const Key('invite_manual_copy')),
        ],
      ],
    );
  }

  Widget _button(SendChannel channel, IconData icon, String label) {
    return OutlinedButton.icon(
      key: Key('invite_${inviteChannelName(channel)}'),
      onPressed: () => _send(channel),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
