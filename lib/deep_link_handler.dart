import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const DeepLinkHandler({required this.child, super.key});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  StreamSubscription<Uri>? _sub;
  AppLinks? _appLinks;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    _sub = _appLinks!.uriLinkStream.listen((Uri uri) async {
      if (_processing) return;
      _processing = true;
      try {
        // Try to get session from URL (Supabase magic link)
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to complete login: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        _processing = false;
      }
    }, onError: (err) {
      // Handle error
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _appLinks = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
