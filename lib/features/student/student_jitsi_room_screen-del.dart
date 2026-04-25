import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StudentJitsiRoomScreen extends StatefulWidget {
  final String roomUrl;
  final String title;
  final String? displayName;
  final String? email;

  const StudentJitsiRoomScreen({
    super.key,
    required this.roomUrl,
    required this.title,
    this.displayName,
    this.email,
  });

  @override
  State<StudentJitsiRoomScreen> createState() =>
      _StudentJitsiRoomScreenState();
}

class _StudentJitsiRoomScreenState extends State<StudentJitsiRoomScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    final customizedUrl = _buildCustomizedJitsiUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(customizedUrl));
  }

  String _escapeJsValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'");
  }

  String _buildCustomizedJitsiUrl() {
    final base = widget.roomUrl.trim();

    final displayName = (widget.displayName ?? '').trim();
    final email = (widget.email ?? '').trim();

    final fragments = <String>[
      'config.defaultLanguage="ar"',
      'config.prejoinPageEnabled=false',
      'config.disableDeepLinking=true',
      'interfaceConfig.APP_NAME="مقرأة التيسير الإلكترونية"',
      'config.startWithAudioMuted=false',
      'config.startWithVideoMuted=false',
      'config.disableModeratorIndicator=true',
      'config.toolbarButtons=["microphone","camera","chat","tileview","hangup"]',
    ];

    if (displayName.isNotEmpty) {
      fragments.add('userInfo.displayName="${_escapeJsValue(displayName)}"');
    }

    if (email.isNotEmpty) {
      fragments.add('userInfo.email="${_escapeJsValue(email)}"');
    }

    final separator = base.contains('#') ? '&' : '#';
    return '$base$separator${fragments.join('&')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}