import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/action_button.dart';

/// RoadSOS Onboarding Screen.
/// Guides new users through core safety features and secures hardware permissions.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _requesting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Request essential device sensors and hardware features.
  Future<void> _requestPermissionsAndStart() async {
    setState(() => _requesting = true);

    if (kIsWeb) {
      await _completeOnboarding();
      return;
    }

    // Location permissions
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();

    // Notification permissions
    await Permission.notification.request();

    // Nearby Devices permissions
    await Permission.bluetoothScan.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.nearbyWifiDevices.request();

    // Microphone permissions
    await Permission.microphone.request();

    await _completeOnboarding();
  }

  /// Write complete state and route to main screen.
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  const _OnboardingPage1(),
                  _OnboardingPage2(
                    onSetupNow: () {
                      context.go('/medical-id');
                    },
                  ),
                  const _OnboardingPage3(),
                ],
              ),
            ),
            // Dots + Button navigation area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                children: [
                  // Smooth animating dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final isSelected = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isSelected ? 24.0 : 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.emergencyRed : AppColors.textMuted,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  if (_currentPage < 2)
                    Row(
                      children: [
                        Expanded(
                          child: ActionButton(
                            "NEXT →",
                            onTap: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            "Skip",
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ActionButton(
                      "GET STARTED",
                      onTap: _requesting ? null : _requestPermissionsAndStart,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic page structure enclosing illustrations and body copy.
class _OnboardingPageContainer extends StatelessWidget {
  final Widget illustration;
  final Widget content;

  const _OnboardingPageContainer({
    required this.illustration,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(child: illustration),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 1: Crash Detection Feature.
class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageContainer(
      illustration: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.emergencyRed.withOpacity(0.06),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(120, 140),
            painter: ShieldPainter(),
          ),
        ),
      ),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Crash Detection",
            style: AppTypography.displayMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          Text(
            "Runs Silently",
            style: AppTypography.displayMedium.copyWith(color: AppColors.emergencyRed),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "RoadSOS monitors your phone in the background. If a crash is detected, it alerts emergency services automatically.",
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Page 2: Medical ID & QR Setup.
class _OnboardingPage2 extends StatelessWidget {
  final VoidCallback onSetupNow;

  const _OnboardingPage2({
    required this.onSetupNow,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageContainer(
      illustration: SizedBox(
        width: 140,
        height: 140,
        child: CustomPaint(
          size: const Size(140, 140),
          painter: QrPainter(),
        ),
      ),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Your Medical ID",
            style: AppTypography.displayMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          Text(
            "Without Unlocking",
            style: AppTypography.displayMedium.copyWith(color: AppColors.infoBlue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Store blood group, allergies, and emergency contacts. Paramedics scan your QR even if your screen is broken.",
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onSetupNow,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              "SET UP MEDICAL ID NOW",
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.emergencyRed,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 3: Phone/Manual SOS button.
class _OnboardingPage3 extends StatelessWidget {
  const _OnboardingPage3();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageContainer(
      illustration: SizedBox(
        width: 140,
        height: 200,
        child: CustomPaint(
          size: const Size(140, 200),
          painter: PhoneSosPainter(),
        ),
      ),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "One Button.",
            style: AppTypography.displayMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          Text(
            "Gets Help Fast.",
            style: AppTypography.displayMedium.copyWith(color: AppColors.safeGreen),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Hold the SOS button for 2 seconds to alert emergency services. Or let crash detection do it automatically.",
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Custom shield outline and pulse waves.
class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw shield outline
    final shieldPath = Path();
    shieldPath.moveTo(width / 2, 0); // top center
    shieldPath.quadraticBezierTo(width * 0.9, height * 0.05, width, height * 0.2); // top right
    shieldPath.quadraticBezierTo(width * 0.95, height * 0.7, width / 2, height); // bottom point
    shieldPath.quadraticBezierTo(width * 0.05, height * 0.7, 0, height * 0.2); // bottom left
    shieldPath.quadraticBezierTo(width * 0.1, height * 0.05, width / 2, 0); // back to top center
    shieldPath.close();

    final shieldPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawPath(shieldPath, shieldPaint);

    // 2. Draw heartbeat pulse line inside shield
    final heartbeatPath = Path();
    heartbeatPath.moveTo(width * 0.2, height * 0.5);
    heartbeatPath.lineTo(width * 0.4, height * 0.5);
    heartbeatPath.lineTo(width * 0.45, height * 0.25); // sharp ECG peak up
    heartbeatPath.lineTo(width * 0.5, height * 0.75); // sharp ECG peak down
    heartbeatPath.lineTo(width * 0.55, height * 0.4); // recovery up
    heartbeatPath.lineTo(width * 0.6, height * 0.5); // back to baseline
    heartbeatPath.lineTo(width * 0.8, height * 0.5);

    final heartbeatPaint = Paint()
      ..color = AppColors.emergencyRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(heartbeatPath, heartbeatPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simplified QR code corner markers.
class QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final redPaint = Paint()
      ..color = AppColors.emergencyRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Corner square dimensions
    const double eyeSize = 40.0;
    const double innerEyeSize = 16.0;

    // Top Left eye
    canvas.drawRect(const Rect.fromLTWH(0, 0, eyeSize, eyeSize), strokePaint);
    canvas.drawRect(const Rect.fromLTWH((eyeSize - innerEyeSize) / 2, (eyeSize - innerEyeSize) / 2, innerEyeSize, innerEyeSize), fillPaint);

    // Top Right eye
    canvas.drawRect(Rect.fromLTWH(width - eyeSize, 0, eyeSize, eyeSize), strokePaint);
    canvas.drawRect(Rect.fromLTWH(width - eyeSize + (eyeSize - innerEyeSize) / 2, (eyeSize - innerEyeSize) / 2, innerEyeSize, innerEyeSize), fillPaint);

    // Bottom Left eye
    canvas.drawRect(Rect.fromLTWH(0, height - eyeSize, eyeSize, eyeSize), strokePaint);
    canvas.drawRect(Rect.fromLTWH((eyeSize - innerEyeSize) / 2, height - eyeSize + (eyeSize - innerEyeSize) / 2, innerEyeSize, innerEyeSize), fillPaint);

    // Scattered modules in the middle region
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    const double dotSize = 8.0;
    final dots = [
      Offset(width * 0.45, height * 0.2),
      Offset(width * 0.55, height * 0.2),
      Offset(width * 0.5, height * 0.35),
      Offset(width * 0.3, height * 0.45),
      Offset(width * 0.7, height * 0.45),
      Offset(width * 0.45, height * 0.65),
      Offset(width * 0.55, height * 0.65),
      Offset(width * 0.8, height * 0.8),
      Offset(width * 0.2, height * 0.6),
      Offset(width * 0.6, height * 0.8),
    ];
    for (var dot in dots) {
      canvas.drawRect(Rect.fromCenter(center: dot, width: dotSize, height: dotSize), dotPaint);
    }

    // Small red safety plus inside QR center
    const double crossSize = 16.0;
    canvas.drawLine(
      Offset(width / 2 - crossSize / 2, height / 2),
      Offset(width / 2 + crossSize / 2, height / 2),
      redPaint,
    );
    canvas.drawLine(
      Offset(width / 2, height / 2 - crossSize / 2),
      Offset(width / 2, height / 2 + crossSize / 2),
      redPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom hand holding device outline.
class PhoneSosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final whiteStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final redStroke = Paint()
      ..color = AppColors.emergencyRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // 1. Phone bezel outline
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(width / 2, height / 2), width: width * 0.65, height: height * 0.95),
      const Radius.circular(16),
    );
    canvas.drawRRect(phoneRect, whiteStroke);

    // 2. SOS Button outline
    const double circleRadius = 40.0;
    canvas.drawCircle(Offset(width / 2, height / 2), circleRadius, redStroke);

    // 3. "SOS" typography center overlay
    final textPainter = TextPainter(
      text: TextSpan(
        text: "SOS",
        style: GoogleFonts.barlowCondensed(
          color: AppColors.emergencyRed,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(width / 2 - textPainter.width / 2, height / 2 - textPainter.height / 2),
    );

    // 4. Multi-layered touch waves (finger arcs)
    final gesturePaint = Paint()
      ..color = AppColors.emergencyRed.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Direct waves expanding out
    canvas.drawArc(
      Rect.fromCircle(center: Offset(width / 2, height / 2), radius: circleRadius + 12.0),
      0.2, // start angle
      1.0, // sweep angle
      false,
      gesturePaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(width / 2, height / 2), radius: circleRadius + 22.0),
      0.3,
      0.8,
      false,
      gesturePaint..color = AppColors.emergencyRed.withOpacity(0.15),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
