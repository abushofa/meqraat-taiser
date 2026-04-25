import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class JitsiRoomScreen extends StatefulWidget {
  final String roomUrl;
  final String title;
  final String? displayName;
  final String? email;
  final bool isTeacher;
  final int? sessionId;
  final VoidCallback? onTeacherEndSession;

  const JitsiRoomScreen({
    super.key,
    required this.roomUrl,
    required this.title,
    this.displayName,
    this.email,
    this.isTeacher = false,
    this.sessionId,
    this.onTeacherEndSession,
  });

  @override
  State<JitsiRoomScreen> createState() => _JitsiRoomScreenState();
}

class _JitsiRoomScreenState extends State<JitsiRoomScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _endingSession = false;

  @override
  void initState() {
    super.initState();

    final customizedUrl = _buildCustomizedJitsiUrl();

    late final PlatformWebViewControllerCreationParams params;

    params = const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params);

    // ✅ هذا هو الحل الأساسي لمشكلة Android
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      androidController.setMediaPlaybackRequiresUserGesture(false);

      androidController.setOnPlatformPermissionRequest((request) {
        request.grant(); // 🔥 يعطي الإذن للموقع
      });
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(customizedUrl));

    _controller = controller;
  }

  String _escapeJsValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'");
  }

  String _buildCustomizedJitsiUrl() {
    final original = Uri.parse(widget.roomUrl.trim());

    final displayName = (widget.displayName ?? '').trim();
    final email = (widget.email ?? '').trim();

    final query = Map<String, String>.from(original.queryParameters);
    query['lang'] = 'ar';

    final baseUri = original.replace(
      queryParameters: query.isEmpty ? null : query,
      fragment: '',
    );

    final toolbarButtons = widget.isTeacher
        ? '["microphone","camera","chat","tileview","participants-pane","hangup"]'
        : '["microphone","camera","chat","tileview","hangup"]';

    final fragments = <String>[
      'config.defaultLanguage="ar"',
      'config.prejoinPageEnabled=false',
      'config.disableDeepLinking=true',
      'config.startWithAudioMuted=false',
      'config.startWithVideoMuted=true',
      'config.disableModeratorIndicator=${widget.isTeacher ? "false" : "true"}',
      'config.toolbarButtons=$toolbarButtons',
      'interfaceConfig.APP_NAME="مقرأة التيسير الإلكترونية"',
    ];

    if (displayName.isNotEmpty) {
      fragments.add('userInfo.displayName="${_escapeJsValue(displayName)}"');
    }

    if (email.isNotEmpty) {
      fragments.add('userInfo.email="${_escapeJsValue(email)}"');
    }

    return '${baseUri.toString()}#${fragments.join('&')}';
  }

  Future<void> _handleTeacherEndSession() async {
    if (_endingSession) return;

    if (widget.onTeacherEndSession == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _endingSession = true;
    });

    try {
      widget.onTeacherEndSession!();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _endingSession = false;
        });
      }
    }
  }

  Future<void> _confirmTeacherEndSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد إنهاء الجلسة'),
          content: const Text('هل تريد إنهاء الجلسة الآن؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إنهاء'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _handleTeacherEndSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          if (widget.isTeacher)
            IconButton(
              icon: const Icon(Icons.call_end),
              onPressed: _endingSession ? null : _confirmTeacherEndSession,
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Container(
              color: Colors.white,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_endingSession)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: widget.isTeacher
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text(
                    _endingSession ? 'جارٍ إنهاء الجلسة...' : 'إنهاء الجلسة',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _endingSession ? null : _confirmTeacherEndSession,
                ),
              ),
            )
          : null,
    );
  }
}
