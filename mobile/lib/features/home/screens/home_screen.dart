import 'dart:async';
import 'package:flutter/material.dart';
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
import '../widgets/home_status_bar.dart';
import '../widgets/location_header.dart';
import '../widgets/home_sos_button.dart';
import '../widgets/quick_services_row.dart';
import '../widgets/nearest_hospital_card.dart';
import '../widgets/protection_status_card.dart';

/// The central Home Screen for RoadSOS, featuring manual SOS controls,
/// active mesh telemetry dots, and hands-free voice trigger capabilities.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc()..add(const HomeStarted()),
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
    _speech.stop();
    super.dispose();
  }

  /// Checks if Voice SOS has been enabled in settings
  Future<void> _loadVoiceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool('voice_sos') ?? false;
    setState(() {
      _voiceSosEnabled = enabled;
    });
    if (enabled) {
      _initSpeech();
    }
  }

  /// Initialises local speech recognition services
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && _isListening && _voiceSosEnabled) {
            _startListening();
          }
        },
        onError: (err) => print("Speech STT error: $err"),
      );
      setState(() {
        _speechAvailable = available;
      });
      if (available) {
        _startListening();
      }
    } catch (_) {
      // Graceful fallback for non-supported device runtimes (e.g. web/emulators)
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  /// Starts listening to device microphone
  void _startListening() async {
    if (!_voiceSosEnabled) return;
    try {
      setState(() {
        _isListening = true;
        _wordsSpoken = "Listening...";
      });
      _pulseController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
          });
          if (result.recognizedWords.toLowerCase().contains("help roadsos")) {
            _triggerVoiceSOS();
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
  void _triggerVoiceSOS() {
    _stopListening();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "🎤 Voice activation trigger detected!",
          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.emergencyRed,
      ),
    );
    context.go('/countdown');
  }

  /// Simulates voice detection physically on mock devices
  void _simulateVoiceTrigger() {
    setState(() {
      _wordsSpoken = "help roadsos";
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _triggerVoiceSOS();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
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
                          onTap: (section) {
                            context.go('/emergency?section=$section');
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
                                  color: AppColors.emergencyRed.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseScale,
                                        builder: (context, _) {
                                          return Transform.scale(
                                            scale: _isListening ? _pulseScale.value : 1.0,
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppColors.emergencyRed.withOpacity(0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.mic_rounded,
                                                size: 16,
                                                color: _isListening
                                                    ? AppColors.emergencyRed
                                                    : AppColors.textMuted,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Voice Activation Active',
                                              style: AppTypography.bodyLarge.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Input: "$_wordsSpoken"',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: _simulateVoiceTrigger,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.emergencyRed.withOpacity(0.12),
                                          elevation: 0,
                                          minimumSize: Size.zero,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          "MOCK SAY",
                                          style: AppTypography.labelCaps.copyWith(
                                            color: AppColors.emergencyRed,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Say 'Help RoadSOS' or click MOCK SAY to trigger",
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Nearest Hospital details
                        NearestHospitalCard(
                          hospital: state.nearestHospital,
                          isLoading: state.isLoading,
                        ),

                        const SizedBox(height: 20),

                        // Sensor and Mesh telemetry statuses
                        ProtectionStatusCard(
                          crashDetectionEnabled: state.crashDetectionEnabled,
                          meshStatus: state.meshStatus,
                          nearbyDevicesCount: state.nearbyDevicesCount,
                          lastDbSync: state.lastDbSync,
                          onCrashDetectionToggled: (_) {
                            context
                                .read<HomeBloc>()
                                .add(const HomeCrashDetectionToggled());
                          },
                        ),

                        const SizedBox(height: 20),

                        // Premium Hackathon Demo Mode Switch Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderSubtle, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.developer_mode_rounded,
                                  size: 20,
                                  color: AppColors.emergencyRed,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hackathon Demo Mode',
                                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        state.isDemoMode
                                            ? 'Ahmedabad location & active mesh locks ENABLED'
                                            : 'Run offline simulations for presenters',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 11,
                                          color: state.isDemoMode
                                              ? AppColors.emergencyRed
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 28,
                                  child: Switch(
                                    value: state.isDemoMode,
                                    onChanged: (_) {
                                      context.read<HomeBloc>().add(const HomeDemoModeToggled());
                                    },
                                    activeThumbColor: AppColors.emergencyRed,
                                    activeTrackColor: AppColors.emergencyRed.withOpacity(0.3),
                                    inactiveThumbColor: AppColors.textMuted,
                                    inactiveTrackColor: AppColors.surfaceAlt,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
