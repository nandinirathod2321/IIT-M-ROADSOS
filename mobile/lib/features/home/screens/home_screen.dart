import 'dart:async';
import 'dart:math' show sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/crash_detection_bar.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../presentation/blocs/location/location_cubit.dart';
import '../widgets/home_status_bar.dart';
import '../widgets/location_header.dart';
import '../widgets/home_sos_button.dart';
import '../widgets/quick_services_row.dart';
import '../widgets/nearest_hospital_card.dart';
import '../widgets/protection_status_card.dart';

import '../../../presentation/blocs/nearby/nearby_cubit.dart';

/// The central Home Screen for RoadSOS, featuring manual SOS controls,
/// active mesh telemetry dots, and hands-free voice trigger capabilities.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => HomeBloc(
        locationCubit: ctx.read<LocationCubit>(),
        responderCubit: ctx.read<NearbyCubit>(),
      )..add(const HomeStarted()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with SingleTickerProviderStateMixin {
  // Voice SOS Trigger system
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _wordsSpoken = "Waiting...";
  bool _voiceSosEnabled = false;
  bool _voiceAlwaysListening = false;
  String _micPermissionStatus = "unknown"; // "unknown", "granted", "denied", "permanentlyDenied", "notSupported"
  double _voiceConfidence = 0.0;
  Timer? _restartTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadVoiceSetting();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _restartTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  /// Checks if Voice SOS has been enabled in settings
  Future<void> _loadVoiceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool('voice_sos') ?? false;
    final bool alwaysListening = prefs.getBool('voice_sos_always_listening') ?? false;
    setState(() {
      _voiceSosEnabled = enabled;
      _voiceAlwaysListening = alwaysListening;
    });
    if (enabled) {
      _initSpeech();
    }
  }

  /// Initialises local speech recognition services and sets up permission states.
  Future<void> _initSpeech() async {
    if (mounted) {
      setState(() {
        _micPermissionStatus = "unknown";
      });
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          print("STT status change: $status");
          if (status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
                _pulseController.stop();
              });
              // Persistent Always-Listening Loop restart
              if (_voiceSosEnabled) {
                _restartTimer?.cancel();
                _restartTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted && _voiceSosEnabled) {
                    _startListening();
                  }
                });
              }
            }
          } else if (status == 'listening') {
            if (mounted) {
              setState(() {
                _isListening = true;
                _pulseController.repeat(reverse: true);
              });
            }
          }
        },
        onError: (err) {
          print("STT error change: $err");
          if (mounted) {
            setState(() {
              _isListening = false;
              _pulseController.stop();
              if (err.errorMsg == 'error_permission') {
                _micPermissionStatus = "denied";
              }
            });
            // Re-trigger scanning loop on non-fatal error status (like speech timeout)
            if (_voiceSosEnabled && err.errorMsg != 'error_permission') {
              _restartTimer?.cancel();
              _restartTimer = Timer(const Duration(milliseconds: 500), () {
                if (mounted && _voiceSosEnabled) {
                  _startListening();
                }
              });
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
          _micPermissionStatus = available ? "granted" : "notSupported";
        });
        if (available && _voiceSosEnabled) {
          _startListening();
        }
      }
    } catch (_) {
      // Graceful fallback for non-supported device runtimes (e.g. web/emulators)
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _micPermissionStatus = "notSupported";
        });
      }
    }
  }

  /// Starts listening to device microphone
  void _startListening() async {
    if (!_voiceSosEnabled) return;
    try {
      setState(() {
        _isListening = true;
        _wordsSpoken = "Listening...";
        _voiceConfidence = 0.0;
        _micPermissionStatus = "granted";
      });
      _pulseController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _wordsSpoken = result.recognizedWords;
              _voiceConfidence = result.confidence;
            });
            final phrase = result.recognizedWords.toLowerCase();
            if (phrase.contains("help roadsos") || phrase.contains("emergency") || phrase.contains("call help")) {
              _triggerVoiceSOS(result.confidence);
            }
          }
        },
      );
    } catch (_) {
      // Suppress crashes
    }
  }

  /// Stops listening to device microphone
  void _stopListening() async {
    await _speech.stop();
    _pulseController.stop();
    setState(() {
      _isListening = false;
    });
  }

  /// Triggers the full SOS emergency routing flow
  void _triggerVoiceSOS(double confidence) {
    _stopListening();
    
    // 1. Device Vibration Feedback
    try {
      HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());
    } catch (_) {}

    // 2. Visual Alert Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "🎤 Voice Trigger Detected! (Confidence: ${(confidence > 0 ? confidence * 100 : 98).toStringAsFixed(0)}%)",
          style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.emergencyRed,
        duration: const Duration(seconds: 3),
      ),
    );

    // 3. Navigation with triggerType query parameter
    context.go('/countdown?trigger=voice');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        // 1. Loading Screen State
        if (state.isLoading && state.latitude == null) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.emergencyRed),
                  SizedBox(height: 16),
                  Text(
                    "RESOLVING GPS POSITION...",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. Permission / GPS Error State Screen
        if (state.hasLocationError) {
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        color: AppColors.emergencyRed,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "GPS LOCATION ACCESS REQUIRED",
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.locationErrorMessage.isNotEmpty
                          ? state.locationErrorMessage
                          : "RoadSOS requires real-time GPS coordinates to determine nearest hospitals, police, and towing services during a critical emergency.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.read<HomeBloc>().add(const HomeStarted());
                        },
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: Text(
                          "RETRY LOCATION ACCESS",
                          style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 13, letterSpacing: 1.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emergencyRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Column(
              children: [
                // Crash detection indicator bar
                CrashDetectionBar(isActive: state.crashDetectionEnabled),

                // Immersive Status bar
                HomeStatusBar(
                  isProtected: state.crashDetectionEnabled,
                  coordinates: state.formattedCoordinates,
                  connectivity: state.connectivity,
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location header
                        LocationHeader(
                          isLoading: state.isLoading,
                          address: state.address,
                          coordinates: state.formattedCoordinates,
                        ),

                        const SizedBox(height: 32),

                        // Large SOS button
                        Center(
                          child: HomeSosButton(
                            crashDetectorActive: state.crashDetectionEnabled,
                            onTriggered: () => context.go('/countdown'),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Quick Ahmedabad spatial query counters
                        QuickServicesRow(
                          hospitalCount: state.nearbyHospitalCount,
                          policeCount: state.nearbyPoliceCount,
                          towingCount: state.nearbyTowingCount,
                          contactsCount: state.contactsCount,
                          isLoading: state.isRespondersLoading,
                          onTap: (section) async {
                            await context.push('/emergency?section=$section');
                          },
                        ),

                        const SizedBox(height: 20),

                        // Voice SOS listening overlay dashboard (shows if voice SOS is armed)
                        if (_voiceSosEnabled) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _micPermissionStatus == 'granted'
                                      ? AppColors.emergencyRed.withOpacity(0.3)
                                      : _micPermissionStatus == 'denied'
                                          ? AppColors.emergencyAmber.withOpacity(0.4)
                                          : AppColors.textMuted.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_micPermissionStatus == 'granted') ...[
                                    Row(
                                      children: [
                                        // Visual listening indicator (pulsing red dot)
                                        AnimatedBuilder(
                                          animation: _pulseScale,
                                          builder: (context, _) {
                                            return Transform.scale(
                                              scale: _isListening ? _pulseScale.value : 1.0,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.emergencyRed,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _isListening ? 'VOICE SOS ACTIVE' : 'VOICE SOS STANDBY',
                                          style: AppTypography.labelCaps.copyWith(
                                            color: AppColors.emergencyRed,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const Spacer(),
                                        // Listening status message
                                        Text(
                                          _isListening ? 'LISTENING' : 'PAUSED',
                                          style: AppTypography.bodySmall.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: _isListening ? AppColors.safeGreen : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Input: "${_wordsSpoken}"',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: _wordsSpoken == "Listening..." || _wordsSpoken == "Waiting..." ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          "Confidence: ${(_voiceConfidence > 0 ? (_voiceConfidence * 100).toStringAsFixed(0) : '--')}%",
                                          style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                        const Spacer(),
                                        Text(
                                          "Trigger: 'Help RoadSOS'",
                                          style: AppTypography.bodySmall.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Animated Waveform Display
                                    Center(
                                      child: _VoiceWaveform(isListening: _isListening),
                                    ),
                                  ] else if (_micPermissionStatus == 'denied') ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.mic_off_rounded, color: AppColors.emergencyAmber, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Microphone Permission Required",
                                                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Hands-free voice trigger SOS requires system microphone access.",
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 38,
                                      child: ElevatedButton.icon(
                                        onPressed: _initSpeech,
                                        icon: const Icon(Icons.settings_voice_rounded, size: 16, color: Colors.white),
                                        label: Text(
                                          "GRANT MICROPHONE ACCESS",
                                          style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 11, letterSpacing: 1.0),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.emergencyAmber,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    // Not Supported or Web Fallback
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: AppColors.textMuted.withOpacity(0.5), size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Hands-Free SOS Restricted",
                                                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Offline hands-free speech trigger is not supported on this platform. Manual SOS is fully active.",
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Nearest Hospital details
                        NearestHospitalCard(
                          hospital: state.nearestHospital,
                          isLoading: state.isRespondersLoading,
                        ),

                        const SizedBox(height: 20),

                        // Sensor and Mesh telemetry statuses
                        ProtectionStatusCard(
                          crashDetectionEnabled: state.crashDetectionEnabled,
                          meshStatus: state.meshStatus,
                          nearbyDevicesCount: state.nearbyDevicesCount,
                          signalQuality: state.signalQuality,
                          syncStatus: state.syncStatus,
                          lastDbSync: state.lastDbSync,
                          onCrashDetectionToggled: (_) {
                            context
                                .read<HomeBloc>()
                                .add(const HomeCrashDetectionToggled());
                          },
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dynamic animated voice waveform rendering a row of vertical neon-red bars
/// that actively scale in height using a sine-wave algorithm when recording.
class _VoiceWaveform extends StatefulWidget {
  final bool isListening;
  const _VoiceWaveform({required this.isListening});

  @override
  State<_VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<_VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isListening) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    } else {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(11, (index) {
              double value = 0.15;
              if (widget.isListening) {
                // Generates sine-wave animated heights
                final radians = (_animController.value * 2 * 3.14159) - (index * 0.55);
                value = (0.2 + 0.8 * (0.5 + 0.5 * sin(radians))).clamp(0.15, 1.0);
              }
              return Container(
                width: 3.5,
                height: 28 * value,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: widget.isListening
                      ? AppColors.emergencyRed
                      : AppColors.textMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isListening
                      ? [
                          BoxShadow(
                            color: AppColors.emergencyRed.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          )
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
