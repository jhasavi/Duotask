import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/task.dart';
import '../models/task_share.dart';
import '../services/task_share_service.dart';

/// Whether [task] can be sent by link. Mirrors the checks in
/// `create_task_share`, so the button only shows when it will work.
bool canSendByLink(Task task, String? userId) =>
    userId != null &&
    task.createdById == userId &&
    task.visibility == TaskVisibility.personal &&
    task.recurrence == TaskRecurrence.none &&
    task.status != TaskStatus.completed;

/// Ways to send the message, in the order they're offered.
enum SendChannel { whatsApp, text, email, copy }

/// The URI that opens [channel] with [message] filled in, or null for
/// [SendChannel.copy].
Uri? sendUri(SendChannel channel, String message, {String? subject}) {
  switch (channel) {
    case SendChannel.whatsApp:
      return Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    case SendChannel.text:
      // "sms:?&body=" is the form both iOS and Android accept.
      return Uri.parse('sms:?&body=${Uri.encodeComponent(message)}');
    case SendChannel.email:
      return Uri(
        scheme: 'mailto',
        query: 'subject=${Uri.encodeComponent(subject ?? 'A task for you')}'
            '&body=${Uri.encodeComponent(message)}',
      );
    case SendChannel.copy:
      return null;
  }
}

Future<void> showSendTaskSheet(BuildContext context, Task task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<TaskShareService>(),
      child: SendTaskSheet(task: task),
    ),
  );
}

/// Sends a task to someone who doesn't have DuoTask: name them, pick
/// WhatsApp, text, email or copy, and the link goes from your own phone.
class SendTaskSheet extends StatefulWidget {
  final Task task;

  /// Opens a URI; injectable for tests.
  final Future<bool> Function(Uri uri)? launcher;

  const SendTaskSheet({super.key, required this.task, this.launcher});

  @override
  State<SendTaskSheet> createState() => _SendTaskSheetState();
}

class _SendTaskSheetState extends State<SendTaskSheet> {
  late final TextEditingController _nameController;
  bool _busy = false;
  String? _error;
  String? _notice;
  String? _manualCopy;

  @override
  void initState() {
    super.initState();
    final service = context.read<TaskShareService>();
    final existing = service.shareFor(widget.task.id);
    _nameController =
        TextEditingController(text: existing?.recipientName ?? '');
    // Get the link ready now, so tapping a button opens WhatsApp or copies
    // straight away. Browsers only allow opening a window or writing the
    // clipboard during the tap itself, not after a network round trip.
    if (existing == null) _createLink();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createLink() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<TaskShareService>().share(widget.task.id);
    } on TaskShareException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _launch(Uri uri) {
    final launcher = widget.launcher;
    if (launcher != null) return launcher(uri);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _send(SendChannel channel) async {
    final service = context.read<TaskShareService>();
    final share = service.shareFor(widget.task.id);
    if (share == null) return;

    final name = _nameController.text.trim();
    final message = TaskShare.buildMessage(
      taskTitle: widget.task.title,
      url: service.urlFor(share),
      recipientName: name,
      dueDate: widget.task.dueDate,
    );
    setState(() {
      _notice = null;
      _manualCopy = null;
    });

    try {
      // Open the app (or copy) first, while still inside the tap.
      final uri = sendUri(channel, message, subject: widget.task.title);
      if (uri == null) {
        await _copy(message, 'Message and link copied. Paste it anywhere.');
      } else if (!await _launchSafely(uri)) {
        await _copy(message,
            "Couldn't open that app, so the message was copied instead.");
      }
    } finally {
      // Then remember who it went to, so the status line can name them.
      if (name.isNotEmpty && name != share.recipientName) {
        try {
          await service.share(widget.task.id, recipientName: name);
        } on TaskShareException {
          // The link works either way; only the label is missing.
        }
      }
    }
  }

  Future<bool> _launchSafely(Uri uri) async {
    try {
      return await _launch(uri);
    } catch (_) {
      return false;
    }
  }

  /// Copies [message], or shows it for copying by hand when the browser
  /// refuses clipboard access. Feedback is shown in the sheet: a snackbar
  /// would sit behind it.
  Future<void> _copy(String message, String done) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) setState(() => _notice = done);
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = "Copying isn't allowed here. Select the message below "
              'and copy it.';
          _manualCopy = message;
        });
      }
    }
  }

  Future<void> _stopSharing() async {
    final service = context.read<TaskShareService>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await service.stopSharing(widget.task.id);
      navigator.pop();
    } on TaskShareException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = context.watch<TaskShareService>().shareFor(widget.task.id);
    final ready = share != null && !_busy;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send to someone', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "They don't need DuoTask. They'll get a link where they can say "
            "they've got it or mark it done, and you'll see it here.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          if (share != null && share.hasActivity) ...[
            const SizedBox(height: 16),
            _ShareStatus(share: share),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('send_task_name'),
            controller: _nameController,
            enabled: !_busy,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Their name (optional)',
              prefixIcon: Icon(Icons.person_outline),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChannelButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                onPressed: ready ? () => _send(SendChannel.whatsApp) : null,
              ),
              _ChannelButton(
                icon: Icons.sms_outlined,
                label: 'Text',
                onPressed: ready ? () => _send(SendChannel.text) : null,
              ),
              _ChannelButton(
                icon: Icons.email_outlined,
                label: 'Email',
                onPressed: ready ? () => _send(SendChannel.email) : null,
              ),
              _ChannelButton(
                icon: Icons.link,
                label: 'Copy link',
                onPressed: ready ? () => _send(SendChannel.copy) : null,
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(_notice!,
                key: const Key('send_task_notice'),
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: _manualCopy == null
                        ? AppTheme.completedColor
                        : AppTheme.textSecondary)),
          ],
          if (_manualCopy != null) ...[
            const SizedBox(height: 8),
            SelectableText(_manualCopy!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.urgentColor)),
          ],
          const SizedBox(height: 16),
          Text(
            "Anyone with the link can see this task's title, notes and due "
            'date. Links expire after 30 days.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          if (share != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _stopSharing,
                icon: const Icon(Icons.link_off),
                label: const Text('Turn off link'),
                style:
                    TextButton.styleFrom(foregroundColor: AppTheme.urgentColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShareStatus extends StatelessWidget {
  final TaskShare share;
  const _ShareStatus({required this.share});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (share.response) {
      case ShareResponse.done:
        icon = Icons.check_circle;
        color = AppTheme.completedColor;
        break;
      case ShareResponse.accepted:
        icon = Icons.thumb_up_alt_outlined;
        color = AppTheme.claimedColor;
        break;
      case ShareResponse.declined:
        icon = Icons.do_not_disturb_on_outlined;
        color = AppTheme.urgentColor;
        break;
      case ShareResponse.pending:
        icon = share.firstOpenedAt != null
            ? Icons.visibility_outlined
            : Icons.schedule_send_outlined;
        color = AppTheme.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(share.statusLine())),
        ],
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ChannelButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// Compact line for the task detail screen showing where a sent link stands.
class TaskShareStatusTile extends StatelessWidget {
  final Task task;
  const TaskShareStatusTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final share = context.watch<TaskShareService>().shareFor(task.id);
    if (share == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.send_outlined),
      title: Text(share.statusLine()),
      subtitle: const Text('Sent by link'),
      onTap: () => showSendTaskSheet(context, task),
    );
  }
}
