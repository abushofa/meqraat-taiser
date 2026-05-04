import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class AgoraCallScreen extends StatefulWidget {
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final String title;
  final String displayName; // اسم الطرف الآخر
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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _pulseOpacity = Tween<double>(
      begin: 0.55,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _initAgora();
    _startPing();
  }

  String _sanitizeAppId(String value) {
    return value.trim();
  }

  String _sanitizeChannel(String value) {
    return value.trim();
  }

  String _sanitizeToken(String value) {
    return value.trim();
  }

  void _startPing() {
  if (!widget.isTeacher) return;

  _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
    try {
      // لازم تمرر session_id في arguments
      /*final sessionId = (ModalRoute.of(context)?.settings.arguments
          as Map?)?['session_id'];*/
      final sessionId = widget.sessionId;

      if (sessionId == null) return;

      final dio = await ApiClient.getInstance();
      await dio.post(
        '/teacher/ping_session.php',
        data: {'session_id': sessionId},
      );
    } catch (_) {}
  });
}

  String _formatDuration(int seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final remainSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$remainSeconds';
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _sessionSeconds++;
      });
    });
  }

  void _updatePulseAnimation() {
    final shouldPulse = _isRemoteSpeaking;
    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _setRemoteSpeaking(bool value) {
    if (!mounted) return;
    if (_isRemoteSpeaking == value) return;

    setState(() {
      _isRemoteSpeaking = value;
    });
    _updatePulseAnimation();
  }

  void _setLocalSpeaking(bool value) {
    if (!mounted) return;
    if (_isLocalSpeaking == value) return;

    setState(() {
      _isLocalSpeaking = value;
    });
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
      if (!_localAudioMuted) {
        _setLocalSpeaking(false);
      }
    });
  }

  bool _isIgnorableAgoraError(ErrorCodeType err, String msg) {
    final combined = '${err.name} $msg'.toLowerCase();

    if (combined.contains('-3')) return true;
    if (combined.contains('interrupted')) return true;
    if (combined.contains('timeout')) return true;
    if (combined.contains('lookup channel timeout')) return true;

    switch (err) {
      case ErrorCodeType.errOk:
      case ErrorCodeType.errAborted:
        return true;
      default:
        return false;
    }
  }

  Future<void> _initAgora() async {
    final appId = _sanitizeAppId(widget.appId);
    final token = _sanitizeToken(widget.token);
    final channelName = _sanitizeChannel(widget.channelName);
    final uid = widget.uid;

    try {
      if (appId.isEmpty) {
        throw Exception('معرّف Agora غير موجود');
      }
      if (appId.length != 32) {
        throw Exception('معرّف Agora غير صحيح');
      }
      if (channelName.isEmpty) {
        throw Exception('اسم القناة غير موجود');
      }
      if (token.isEmpty) {
        throw Exception('رمز الدخول غير موجود');
      }
      if (uid <= 0) {
        throw Exception('معرّف المستخدم غير صحيح');
      }

      _engine = createAgoraRtcEngine();
      _engineCreated = true;

      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) async {
            if (!mounted) return;

            await _engine.setEnableSpeakerphone(true);

            setState(() {
              _joined = true; // 🔥 هذا هو الحل الرئيسي
              _errorText = null;
              _connectionStatus = 'متصل، بانتظار الطرف الآخر...';
            });

            _startSessionTimer();
          },
          onUserJoined: (connection, remoteUid, elapsed) async {
            if (!mounted) return;

            await _engine.setEnableSpeakerphone(true); // 👈 تأكيد إضافي

            setState(() {
              _remoteUid = remoteUid;
              _connectionStatus = 'الجلسة متصلة';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            debugPrint('AGORA REMOTE OFFLINE: $remoteUid');
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
          onRemoteVideoStateChanged:
              (connection, remoteUid, state, reason, elapsed) {
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
            debugPrint('AGORA STATE: $state / REASON: $reason');
            if (!mounted) return;

            if (state == ConnectionStateType.connectionStateConnecting) {
              setState(() {
                _connectionStatus = 'جارٍ الاتصال...';
                if (!_joined) {
                  _errorText = null;
                }
              });
            } else if (state ==
                ConnectionStateType.connectionStateReconnecting) {
              setState(() {
                _connectionStatus = 'جارٍ إعادة الاتصال...';
              });
            } else if (state == ConnectionStateType.connectionStateConnected) {
              setState(() {
                _errorText = null;
                _connectionStatus = _remoteUid == null
                    ? 'متصل، بانتظار الطرف الآخر...'
                    : 'الجلسة متصلة';
              });
            } else if (state ==
                ConnectionStateType.connectionStateDisconnected) {
              setState(() {
                _connectionStatus = 'انقطع الاتصال';
              });
            } else if (state == ConnectionStateType.connectionStateFailed) {
              if (!_joined) {
                setState(() {
                  _errorText = 'فشل الاتصال';
                });
              }
            }
          },

          onActiveSpeaker: (connection, speakerUid) {
            if (!mounted) return;
            if (speakerUid != 0) {
              _markRemoteSpeaking();
            }
          },

          onAudioVolumeIndication:
              (connection, speakers, speakerNumber, totalVolume) {
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

                if (localDetected && !_localAudioMuted) {
                  _markLocalSpeaking();
                }

                if (remoteDetected) {
                  _markRemoteSpeaking();
                }
              },

          onError: (err, msg) {
            debugPrint('AGORA ERROR: $err - $msg');

            if (_isIgnorableAgoraError(err, msg)) {
              return;
            }

            if (!mounted) return;

            if (_joined) {
              return;
            }

            setState(() {
              _errorText = 'حدث خطأ في الاتصال';
            });
          },
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      await _engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
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
      debugPrint('AGORA JOIN PARAMS => channel: $channelName | uid: $uid | token length: ${token.length}');
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
      await _engine.setEnableSpeakerphone(true);
      //await _engine.setEnableSpeakerphone(true);
    } catch (e) {
      final errorString = e.toString();
      debugPrint('AGORA INIT EXCEPTION: $errorString');

      if (errorString.contains('AgoraRtcException(-3') ||
          errorString.contains('AgoraRtcException(-3, null)')) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorText = 'تعذر بدء الاتصال';
      });
    }
  }

  Future<void> _toggleMute() async {
    if (!_engineReady) return;

    final newValue = !_localAudioMuted;
    await _engine.muteLocalAudioStream(newValue);

    if (!mounted) return;
    setState(() {
      _localAudioMuted = newValue;
      if (newValue) {
        _isLocalSpeaking = false;
      }
    });
  }

  /*Future<void> _toggleSpeaker() async {
    if (!_engineReady) return;

    final newValue = !_speakerEnabled;
    await _engine.setEnableSpeakerphone(newValue);

    if (!mounted) return;
    setState(() {
      _speakerEnabled = newValue;
    });
  }*/

  Future<void> _toggleSpeaker() async {
    if (!_engineReady) return;

    final newValue = !_speakerEnabled;

    try {
      await _engine.setEnableSpeakerphone(newValue);

      // 🔥 إعادة تأكيد بعد لحظة (حل مشكلة الضغط مرتين)
      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          await _engine.setEnableSpeakerphone(newValue);
        } catch (_) {}
      });

      if (!mounted) return;
      setState(() {
        _speakerEnabled = newValue;
      });
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
        const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
    } else {
      await _engine.muteLocalVideoStream(true);
      await _engine.stopPreview();
      await _engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: false,
          publishMicrophoneTrack: true,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _localVideoEnabled = newValue;
    });
  }

  Future<void> _requestVideo() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تشغيل الفيديو'),
          content: const Text(
            'سيتم تشغيل الفيديو من هذا الطرف مباشرة.\n'
            'ويمكن لاحقًا تطويرها لتكون بموافقة الطرفين.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_localVideoEnabled ? 'إيقاف' : 'تشغيل'),
            ),
          ],
        );
      },
    );

    if (approved == true) {
      await _toggleLocalVideoDirectly();
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنهاء الجلسة'),
        content: const Text('هل تريد مغادرة الجلسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (leave == true) {
      await _leaveCall();
    }
  }

  Future<void> _leaveCall() async {
    if (_ending) return;

    setState(() {
      _ending = true;
    });

    try {
      if (widget.onEndSession != null && widget.isTeacher) {
        await widget.onEndSession!();
      }

      if (_engineCreated) {
        await _engine.leaveChannel();
      }
    } catch (_) {}

    try {
      if (_engineCreated) {
        await _engine.release();
      }
    } catch (_) {}

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
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.45),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ]
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
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
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ]
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
    _pulseController.dispose();
    if (_engineCreated) {
      _engine.release();
    }
    _pingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !_engineReady && _errorText == null;

    return WillPopScope(
      onWillPop: () async {
        await _confirmLeave();
        return false;
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
              Text(
                _connectionStatus,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        backgroundColor ??
        (isActive ? const Color(0xFF2563EB) : const Color(0xFF1E293B));

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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
