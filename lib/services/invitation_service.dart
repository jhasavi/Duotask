import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// Service for handling various invitation methods
class InvitationService {
  static const String _appName = 'DuoTask';
  static const String _appStoreUrl = 'https://apps.apple.com/app/duotask'; // Replace with actual URL
  static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.duotask.app'; // Replace with actual URL

  /// Generate a unique invitation code for the user
  Future<String> generateInvitationCode(String userId) async {
    // For now, we'll use a simple hash of the user ID
    // In production, you might want to generate a more sophisticated code
    final code = _generateSimpleCode(userId);
    return code;
  }

  /// Generate a simple invitation code
  String _generateSimpleCode(String userId) {
    // Create a 6-character code from the user ID
    final hash = userId.hashCode.abs();
    final code = (hash % 1000000).toString().padLeft(6, '0');
    return code;
  }

  /// Share invitation via SMS
  Future<bool> shareViaSMS(String invitationCode, String recipientName) async {
    try {
      final message = _buildSMSMessage(invitationCode, recipientName);
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      Log.error('Failed to share via SMS: $e');
      return false;
    }
  }

  /// Share invitation via WhatsApp
  Future<bool> shareViaWhatsApp(String invitationCode, String recipientName) async {
    try {
      final message = _buildWhatsAppMessage(invitationCode, recipientName);
      final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      Log.error('Failed to share via WhatsApp: $e');
      return false;
    }
  }

  /// Share invitation via general sharing
  Future<bool> shareInvitation(String invitationCode, String recipientName) async {
    try {
      final message = _buildGeneralMessage(invitationCode, recipientName);
      await Share.share(
        message,
        subject: 'Join me on DuoTask!',
      );
      return true; // Share.share doesn't return a status in newer versions
    } catch (e) {
      Log.error('Failed to share invitation: $e');
      return false;
    }
  }

  /// Generate QR code for invitation
  Future<Uint8List?> generateQRCode(String invitationCode) async {
    try {
      final qrPainter = QrPainter(
        data: invitationCode,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/invitation_qr.png';
      
      final picData = await qrPainter.toImageData(200);
      if (picData != null) {
        final file = File(path);
        await file.writeAsBytes(picData.buffer.asUint8List());
        return picData.buffer.asUint8List();
      }
      return null;
    } catch (e) {
      Log.error('Failed to generate QR code: $e');
      return null;
    }
  }

  /// Copy invitation code to clipboard
  Future<bool> copyToClipboard(String invitationCode) async {
    try {
      await Clipboard.setData(ClipboardData(text: invitationCode));
      return true;
    } catch (e) {
      Log.error('Failed to copy to clipboard: $e');
      return false;
    }
  }

  /// Share invitation via email
  Future<bool> shareViaEmail(String invitationCode, String recipientName) async {
    try {
      final subject = 'Join me on DuoTask!';
      final body = _buildEmailMessage(invitationCode, recipientName);
      final uri = Uri.parse('mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      Log.error('Failed to share via email: $e');
      return false;
    }
  }

  /// Share invitation via Telegram
  Future<bool> shareViaTelegram(String invitationCode, String recipientName) async {
    try {
      final message = _buildTelegramMessage(invitationCode, recipientName);
      final uri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(_getAppStoreUrl())}&text=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      Log.error('Failed to share via Telegram: $e');
      return false;
    }
  }

  /// Get the appropriate app store URL based on platform
  String _getAppStoreUrl() {
    if (Platform.isIOS) {
      return _appStoreUrl;
    } else {
      return _playStoreUrl;
    }
  }

  /// Build SMS message
  String _buildSMSMessage(String invitationCode, String recipientName) {
    return '''Hey $recipientName! 

I'd love to share tasks with you on DuoTask! 

Use my invitation code: $invitationCode

Download DuoTask here: ${_getAppStoreUrl()}

Let's stay organized together! 📱✨''';
  }

  /// Build WhatsApp message
  String _buildWhatsAppMessage(String invitationCode, String recipientName) {
    return '''Hey $recipientName! 👋

I'd love to share tasks with you on DuoTask! 

Use my invitation code: *$invitationCode*

Download DuoTask here: ${_getAppStoreUrl()}

Let's stay organized together! 📱✨''';
  }

  /// Build Telegram message
  String _buildTelegramMessage(String invitationCode, String recipientName) {
    return '''Hey $recipientName! 👋

I'd love to share tasks with you on DuoTask! 

Use my invitation code: `$invitationCode`

Download DuoTask here: ${_getAppStoreUrl()}

Let's stay organized together! 📱✨''';
  }

  /// Build general sharing message
  String _buildGeneralMessage(String invitationCode, String recipientName) {
    return '''Hey $recipientName! 

I'd love to share tasks with you on DuoTask! 

Use my invitation code: $invitationCode

Download DuoTask here: ${_getAppStoreUrl()}

Let's stay organized together! 📱✨''';
  }

  /// Build email message
  String _buildEmailMessage(String invitationCode, String recipientName) {
    return '''Hi $recipientName,

I hope this email finds you well! I wanted to invite you to join me on DuoTask, a fantastic app for sharing and managing tasks together.

DuoTask makes it super easy to:
• Create shared task lists
• See real-time updates
• Stay organized as a team
• Never miss important tasks

To get started, please:
1. Download DuoTask from: ${_getAppStoreUrl()}
2. Use my invitation code: $invitationCode
3. We'll be connected and can start sharing tasks!

I think this will really help us stay on top of things together. Let me know if you have any questions!

Best regards''';
  }

  /// Get available sharing methods
  List<InvitationMethod> getAvailableMethods() {
    return [
      InvitationMethod(
        id: 'sms',
        name: 'SMS',
        icon: '📱',
        description: 'Send via text message',
        color: Colors.green,
      ),
      InvitationMethod(
        id: 'whatsapp',
        name: 'WhatsApp',
        icon: '💬',
        description: 'Share via WhatsApp',
        color: Colors.green,
      ),
      InvitationMethod(
        id: 'telegram',
        name: 'Telegram',
        icon: '✈️',
        description: 'Share via Telegram',
        color: Colors.blue,
      ),
      InvitationMethod(
        id: 'email',
        name: 'Email',
        icon: '📧',
        description: 'Send via email',
        color: Colors.orange,
      ),
      InvitationMethod(
        id: 'qr',
        name: 'QR Code',
        icon: '📱',
        description: 'Show QR code to scan',
        color: Colors.purple,
      ),
      InvitationMethod(
        id: 'copy',
        name: 'Copy Code',
        icon: '📋',
        description: 'Copy invitation code',
        color: Colors.grey,
      ),
      InvitationMethod(
        id: 'share',
        name: 'Share',
        icon: '📤',
        description: 'Share via any app',
        color: Colors.blue,
      ),
    ];
  }
}

/// Model for invitation methods
class InvitationMethod {
  final String id;
  final String name;
  final String icon;
  final String description;
  final Color color;

  InvitationMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
  });
}
