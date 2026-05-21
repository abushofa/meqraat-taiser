import 'dart:async';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/network/api_client.dart';
import 'package:audio_session/audio_session.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SessionTaskHandler());
}

class SessionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground task started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    debugPrint('Session alive: ${timestamp.toIso8601String()}');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('Foreground task destroyed');
  }
}

class AgoraCallScreen extends StatefulWidget {
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final String title;
  final String displayName;
  final bool isTeacher;
  final Future<void> Function()? onEndSession;
  final int? sessionId;

  const AgoraCallScreen({
    super.key,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.uid,
    required this.title,
    required this.displayName,
    this.isTeacher = false,
    this.onEndSession,
    this.sessionId,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final RtcEngine _engine;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  bool _engineCreated = false;
  bool _engineReady = false;
  bool _joined = false;
  bool _localAudioMuted = false;
  bool _localVideoEnabled = false;
  bool _speakerEnabled = true;
  bool _ending = false;

  bool _isRecording = false;
  String? _lastRecordingPath;

  int? _remoteUid;
  bool _remoteVideoEnabled = false;

  bool _isLocalSpeaking = false;
  bool _isRemoteSpeaking = false;

  String? _errorText;
  String _connectionStatus = 'جارٍ الاتصال...';

  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  Timer? _remoteSpeakingResetTimer;
  Timer? _localSpeakingResetTimer;
  Timer? _pingTimer;
  Timer? _xiaomiAudioTimer;
  bool _isXiaomi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.isTeacher) _initForegroundService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _initAgora();
    _startPing();
  }

  Future<void> _initForegroundService() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'quran_session_channel',
          channelName: 'جلسة القرآن',
          channelDescription: 'تشغيل جلسة القرآن في الخلفية',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      await FlutterForegroundTask.requestNotificationPermission();
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();

      await FlutterForegroundTask.startService(
        notificationTitle: 'جلسة قرآن نشطة',
        notificationText: 'الجلسة تعمل في الخلفية',
        callback: startCallback,
      );
    } catch (e) {
      debugPrint("Foreground Service Error: $e");
    }
  }

  String _sanitizeAppId(String v) => v.trim();
  String _sanitizeChannel(String v) => v.trim();
  String _sanitizeToken(String v) => v.trim();

  void _startPing() {
    if (!widget.isTeacher) return;
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final sessionId = widget.sessionId;
        if (sessionId == null) return;
        final dio = await ApiClient.getInstance();
        await dio.post('/teacher/ping_session.php', data: {'session_id': sessionId});
      } catch (_) {}
    });
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _sessionSeconds++);
    });
  }

  void _updatePulseAnimation() {
    if (_isRemoteSpeaking) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _setRemoteSpeaking(bool value) {
    if (!mounted || _isRemoteSpeaking == value) return;
    setState(() => _isRemoteSpeaking = value);
    _updatePulseAnimation();
  }

  void _setLocalSpeaking(bool value) {
    if (!mounted || _isLocalSpeaking == value) return;
    setState(() => _isLocalSpeaking = value);
  }

  void _markRemoteSpeaking() {
    _remoteSpeakingResetTimer?.cancel();
    _setRemoteSpeaking(true);
    _remoteSpeakingResetTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _setRemoteSpeaking(false);
    });
  }

  void _markLocalSpeaking() {
    _localSpeakingResetTimer?.cancel();
    _setLocalSpeaking(true);
    _localSpeakingResetTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (!_localAudioMuted) _setLocalSpeaking(false);
    });
  }

  bool _isIgnorableAgoraError(ErrorCodeType err, String msg) {
    final combined = '${err.name} $msg'.toLowerCase();
    if (combined.contains('-3')) return true;
    if (combined.contains('interrupted')) return true;
    if (combined.contains('timeout')) return true;
    switch (err) {
      case ErrorCodeType.errOk:
      case ErrorCodeType.errAborted:
        return true;
      default:
        return false;
    }
  }

  Future<String> _getDeviceManufacturer() async {
    if (!Platform.isAndroid) return '';
    try {
      final result = await _mediaScanner.invokeMethod<String>('getManufacturer');
      return result?.toLowerCase() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _startXiaomiAudioWatchdog() {
    _xiaomiAudioTimer?.cancel();
    // MIUI can silently kill the audio thread after notifications or screen lock.
    // Periodically calling enableAudio() restarts it if suspended.
    _xiaomiAudioTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || !_engineReady) return;
      try {
        await _engine.enableAudio();
        await _setSpeakerOn();
      } catch (_) {}
    });
  }

  Future<void> _setSpeakerOn() async {
    await _engine.setEnableSpeakerphone(true);
    if (Platform.isIOS) {
      await _engine.setDefaultAudioRouteToSpeakerphone(true);
    }
  }

  Future<void> _initAgora() async {
    final appId = _sanitizeAppId(widget.appId);
    final token = _sanitizeToken(widget.token);
    final channelName = _sanitizeChannel(widget.channelName);
    final uid = widget.uid;

    try {
      if (appId.isEmpty) throw Exception('معرّف Agora غير موجود');
      if (appId.length != 32) throw Exception('معرّف Agora غير صحيح');
      if (channelName.isEmpty) throw Exception('اسم القناة غير موجود');
      if (token.isEmpty) throw Exception('رمز الدخول غير موجود');
      if (uid <= 0) throw Exception('معرّف المستخدم غير صحيح');

      _engine = createAgoraRtcEngine();
      _engineCreated = true;

      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: Platform.isIOS
            ? AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp |
              AVAudioSessionCategoryOptions.defaultToSpeaker
            : AVAudioSessionCategoryOptions.allowBluetooth,
        // defaultMode avoids earpiece routing that voiceChat enforces on iOS.
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);
      await Future.delayed(const Duration(milliseconds: 500));

      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      final manufacturer = await _getDeviceManufacturer();
      _isXiaomi = manufacturer.contains('xiaomi') || manufacturer.contains('redmi');

      if (Platform.isIOS) {
        await _engine.setDefaultAudioRouteToSpeakerphone(true);
      }

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) async {
            if (!mounted) return;
            await _setSpeakerOn();
            if (Platform.isIOS) {
              await Future.delayed(const Duration(milliseconds: 500));
              await _setSpeakerOn();
            }
            if (_isXiaomi) _startXiaomiAudioWatchdog();
            setState(() {
              _joined = true;
              _errorText = null;
              _connectionStatus = 'متصل، بانتظار الطرف الآخر...';
            });
            _startSessionTimer();
          },
          onUserJoined: (connection, remoteUid, elapsed) async {
            if (!mounted) return;
            await _setSpeakerOn();
            if (Platform.isIOS) {
              await Future.delayed(const Duration(milliseconds: 500));
              await _setSpeakerOn();
              // Re-activate the audio session after Agora starts receiving the remote stream,
              // because Agora's internal audio setup can reset the speaker routing on iOS.
              Future.delayed(const Duration(milliseconds: 1500), () async {
                if (!mounted || !_engineReady) return;
                try {
                  final audioSession = await AudioSession.instance;
                  await audioSession.setActive(true);
                } catch (_) {}
                await _setSpeakerOn();
              });
            }
            setState(() {
              _remoteUid = remoteUid;
              _connectionStatus = 'الجلسة متصلة';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              if (_remoteUid == remoteUid) {
                _remoteUid = null;
                _remoteVideoEnabled = false;
                _isRemoteSpeaking = false;
              }
              _connectionStatus = 'خرج الطرف الآخر من الجلسة';
            });
            _remoteSpeakingResetTimer?.cancel();
            _updatePulseAnimation();
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            if (!mounted) return;
            setState(() {
              if (_remoteUid == remoteUid) {
                _remoteVideoEnabled =
                    state == RemoteVideoState.remoteVideoStateStarting ||
                    state == RemoteVideoState.remoteVideoStateDecoding ||
                    state == RemoteVideoState.remoteVideoStateFrozen;
              }
            });
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            if (state == ConnectionStateType.connectionStateConnecting) {
              setState(() {
                _connectionStatus = 'جارٍ الاتصال...';
                if (!_joined) _errorText = null;
              });
            } else if (state == ConnectionStateType.connectionStateReconnecting) {
              setState(() => _connectionStatus = 'جارٍ إعادة الاتصال...');
            } else if (state == ConnectionStateType.connectionStateConnected) {
              setState(() {
                _errorText = null;
                _connectionStatus = _remoteUid == null
                    ? 'متصل، بانتظار الطرف الآخر...'
                    : 'الجلسة متصلة';
              });
            } else if (state == ConnectionStateType.connectionStateDisconnected) {
              setState(() => _connectionStatus = 'انقطع الاتصال');
            } else if (state == ConnectionStateType.connectionStateFailed) {
              if (!_joined) setState(() => _errorText = 'فشل الاتصال: ${reason.name}');
            }
          },
          onActiveSpeaker: (connection, speakerUid) {
            if (!mounted) return;
            if (speakerUid != 0) _markRemoteSpeaking();
          },
          onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
            if (!mounted) return;
            bool localDetected = false;
            bool remoteDetected = false;
            for (final speaker in speakers) {
              final volume = speaker.volume ?? 0;
              final speakerUid = speaker.uid ?? 0;
              if (volume > 6) {
                if (speakerUid == 0) {
                  localDetected = true;
                } else if (_remoteUid != null && speakerUid == _remoteUid) {
                  remoteDetected = true;
                } else if (_remoteUid == null && speakerUid != 0) {
                  remoteDetected = true;
                }
              }
            }
            if (localDetected && !_localAudioMuted) _markLocalSpeaking();
            if (remoteDetected) _markRemoteSpeaking();
          },
          onError: (err, msg) {
            debugPrint('AGORA ERROR: $err - $msg');
            if (_isIgnorableAgoraError(err, msg)) return;
            if (!mounted) return;
            if (_joined) return;
            setState(() => _errorText = 'خطأ: ${err.name} ($msg)');
          },
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      await _engine.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQuality,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      await _engine.enableAudio();
      await _engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      await _engine.disableVideo();

      if (!mounted) return;
      setState(() {
        _engineReady = true;
        _connectionStatus = 'جارٍ الاتصال...';
      });

      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      await _setSpeakerOn();
      if (Platform.isIOS) {
        // Re-activate after joinChannel because Agora may reconfigure the session internally.
        await Future.delayed(const Duration(milliseconds: 800));
        final audioSession = await AudioSession.instance;
        await audioSession.setActive(true);
        await _setSpeakerOn();
      }
    } catch (e) {
      final err = e.toString();
      debugPrint('AGORA INIT EXCEPTION: $err');
      if (err.contains('AgoraRtcException(-3')) return;
      if (!mounted) return;
      setState(() => _errorText = 'تعذر بدء الاتصال');
    }
  }

  static final _mediaScanner = const MethodChannel('com.abushofa.quran_app/media_scanner');


  Future<String> _getRecordingPath() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'session_$timestamp.aac';

    if (Platform.isAndroid) {
      // Record to temp cache; after stopping we move to Downloads via MediaStore
      // so files are visible on Xiaomi/Huawei without MANAGE_ALL_FILES permission.
      final dir = await getTemporaryDirectory();
      return '${dir.path}/$fileName';
    } else {
      // .aac is the Agora-documented encoded format; .m4a is not recognized.
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$fileName';
    }
  }

  Future<void> _startRecording() async {
    if (!_engineReady) return;
    try {
      final path = await _getRecordingPath();
      debugPrint('Recording path: $path');
      await _engine.startAudioRecording(
        AudioRecordingConfiguration(
          filePath: path,
          encode: true,
          sampleRate: 48000,
          fileRecordingType: AudioFileRecordingType.audioFileRecordingMixed,
          quality: Platform.isIOS
              ? AudioRecordingQualityType.audioRecordingQualityUltraHigh
              : AudioRecordingQualityType.audioRecordingQualityHigh,
        ),
      );
      debugPrint('Agora recording started: $path');
      _lastRecordingPath = path;
      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Recording start error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل بدء التسجيل: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_engineReady) return;
    try {
      await _engine.stopAudioRecording();
      debugPrint('Agora recording stopped');

      if (_lastRecordingPath != null) {
        final file = File(_lastRecordingPath!);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('File size: $size bytes');
          if (Platform.isAndroid) {
            // Move temp file to public Downloads via MediaStore (works on Xiaomi/Huawei).
            final fileName = _lastRecordingPath!.split('/').last;
            try {
              await _mediaScanner.invokeMethod('saveToDownloads', {
                'path': _lastRecordingPath,
                'fileName': fileName,
              });
              debugPrint('Saved to Downloads: $fileName');
            } catch (e) {
              debugPrint('saveToDownloads error: $e');
            }
          }
        } else {
          debugPrint('File does not exist!');
        }
      }

      if (!mounted) return;
      setState(() => _isRecording = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isIOS
                ? 'تم حفظ التسجيل في تطبيق الملفات ✅'
                : 'تم حفظ التسجيل في مجلد التنزيلات ✅',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Recording stop error: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _toggleMute() async {
    if (!_engineReady) return;
    final newValue = !_localAudioMuted;
    await _engine.muteLocalAudioStream(newValue);
    if (!mounted) return;
    setState(() {
      _localAudioMuted = newValue;
      if (newValue) _isLocalSpeaking = false;
    });
  }

  Future<void> _toggleSpeaker() async {
    if (!_engineReady) return;
    final newValue = !_speakerEnabled;
    try {
      await _engine.setEnableSpeakerphone(newValue);
      if (Platform.isIOS && newValue) {
        await _engine.setDefaultAudioRouteToSpeakerphone(true);
      }
      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          await _engine.setEnableSpeakerphone(newValue);
        } catch (_) {}
      });
      if (!mounted) return;
      setState(() => _speakerEnabled = newValue);
    } catch (_) {}
  }

  Future<void> _toggleLocalVideoDirectly() async {
    if (!_engineReady) return;
    final newValue = !_localVideoEnabled;
    if (newValue) {
      await _engine.enableVideo();
      await _engine.startPreview();
      await _engine.muteLocalVideoStream(false);
      await _engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishCameraTrack: true, publishMicrophoneTrack: true),
      );
    } else {
      await _engine.muteLocalVideoStream(true);
      await _engine.stopPreview();
      await _engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishCameraTrack: false, publishMicrophoneTrack: true),
      );
    }
    if (!mounted) return;
    setState(() => _localVideoEnabled = newValue);
  }

  Future<void> _requestVideo() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تشغيل الفيديو'),
        content: const Text(
          'سيتم تشغيل الفيديو من هذا الطرف مباشرة.\n'
          'ويمكن لاحقًا تطويرها لتكون بموافقة الطرفين.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_localVideoEnabled ? 'إيقاف' : 'تشغيل'),
          ),
        ],
      ),
    );
    if (approved == true) await _toggleLocalVideoDirectly();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنهاء الجلسة'),
        content: const Text('هل تريد مغادرة الجلسة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم')),
        ],
      ),
    );
    if (leave == true) await _leaveCall();
  }

  Future<void> _leaveCall() async {
    if (_ending) return;
    setState(() => _ending = true);

    try {
      if (_isRecording && _engineCreated) {
        await _engine.stopAudioRecording();
        if (_lastRecordingPath != null && Platform.isAndroid) {
          final file = File(_lastRecordingPath!);
          if (await file.exists()) {
            try {
              final fileName = _lastRecordingPath!.split('/').last;
              await _mediaScanner.invokeMethod('saveToDownloads', {
                'path': _lastRecordingPath,
                'fileName': fileName,
              });
            } catch (_) {}
          }
        }
        setState(() => _isRecording = false);
      }

      if (widget.isTeacher && widget.onEndSession != null) {
        await widget.onEndSession!();
      }
      if (_engineCreated) await _engine.leaveChannel();
      if (_engineCreated) await _engine.release();
      if (widget.isTeacher) await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint("LEAVE ERROR: $e");
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildRemoteLogo(bool highlightRemote) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (highlightRemote)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseScale.value,
                  child: Opacity(
                    opacity: _pulseOpacity.value,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.greenAccent, width: 6),
                      ),
                    ),
                  ),
                );
              },
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              boxShadow: highlightRemote
                  ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 3)]
                  : [],
              border: Border.all(
                color: highlightRemote ? Colors.greenAccent : Colors.white24,
                width: highlightRemote ? 3 : 1,
              ),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteArea() {
    final bool highlightRemote = _isRemoteSpeaking;

    if (_remoteUid != null && _remoteVideoEnabled && _engineReady) {
      return Stack(
        children: [
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            ),
          ),
          if (highlightRemote)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 4),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF111827)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRemoteLogo(highlightRemote),
          const SizedBox(height: 16),
          Text(
            widget.displayName.isNotEmpty ? widget.displayName : 'الطرف الآخر',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _remoteUid == null
                ? 'بانتظار دخول الطرف الآخر'
                : 'الفيديو غير مفعّل لدى الطرف الآخر',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLocalPreview() {
    final bool highlightLocal = _isLocalSpeaking && _localVideoEnabled;

    if (!_localVideoEnabled || !_engineReady) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off, color: Colors.white70, size: 28),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlightLocal ? Colors.greenAccent : Colors.white24,
          width: highlightLocal ? 3 : 1,
        ),
        boxShadow: highlightLocal
            ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 3)]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _remoteSpeakingResetTimer?.cancel();
    _localSpeakingResetTimer?.cancel();
    _xiaomiAudioTimer?.cancel();
    _pulseController.dispose();
    if (_engineCreated) _engine.release();
    _pingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isXiaomi && _engineReady) {
      // MIUI may have suspended the audio thread while in background.
      _engine.enableAudio();
      _setSpeakerOn();
    }
    if (!widget.isTeacher) return;
    if (state == AppLifecycleState.paused) {
      _engine.setEnableSpeakerphone(_speakerEnabled);
      debugPrint("Teacher went to background - session continues");
    } else if (state == AppLifecycleState.resumed) {
      _engine.setEnableSpeakerphone(_speakerEnabled);
      debugPrint("Teacher resumed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !_engineReady && _errorText == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        appBar: AppBar(
          backgroundColor: const Color(0xFF020617),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title),
              const SizedBox(height: 2),
              Text(_connectionStatus, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            if (_isRecording)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Center(child: _RecordingIndicator()),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: _StatusChip(
                  icon: Icons.timer_outlined,
                  label: _formatDuration(_sessionSeconds),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorText != null && !_joined)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  Positioned.fill(child: _buildRemoteArea()),
                  Positioned(
                    top: 16,
                    left: 16,
                    width: 124,
                    height: 186,
                    child: _buildLocalPreview(),
                  ),
                ],
              ),
            if (_ending)
              Container(
                color: Colors.black38,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          color: const Color(0xFF020617),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: _localAudioMuted ? Icons.mic_off : Icons.mic,
                label: _localAudioMuted ? 'فتح المايك' : 'كتم المايك',
                onTap: _toggleMute,
                isActive: !_localAudioMuted,
              ),
              _ControlButton(
                icon: _speakerEnabled ? Icons.volume_up : Icons.hearing,
                label: _speakerEnabled ? 'السماعة' : 'سماعة الأذن',
                onTap: _toggleSpeaker,
                isActive: _speakerEnabled,
              ),
              _ControlButton(
                icon: _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
                label: _localVideoEnabled ? 'إيقاف الفيديو' : 'تشغيل الفيديو',
                onTap: _requestVideo,
                isActive: _localVideoEnabled,
              ),
              _ControlButton(
                icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                label: _isRecording ? 'إيقاف' : 'تسجيل',
                onTap: _toggleRecording,
                backgroundColor: _isRecording ? Colors.orange : Colors.red.shade800,
                isActive: true,
              ),
              _ControlButton(
                icon: Icons.call_end,
                label: 'إنهاء',
                onTap: _confirmLeave,
                backgroundColor: Colors.red,
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 14),
          SizedBox(width: 4),
          Text('REC', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.backgroundColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? (isActive ? const Color(0xFF2563EB) : const Color(0xFF1E293B));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 68,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}