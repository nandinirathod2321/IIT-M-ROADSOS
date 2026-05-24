import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Interactive First Aid and Offline Accident Response Guide.
/// Offers structured, offline-ready emergency guidelines and expandables.
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          'EMERGENCY FIRST AID',
          style: AppTypography.headlineLarge.copyWith(letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emergencyAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.emergencyAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.emergencyAmber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OFFLINE FIRST-AID PROTOCOLS",
                          style: AppTypography.labelCaps.copyWith(
                            color: AppColors.emergencyAmber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "All guides are fully stored locally and available without network connection.",
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Expandable safety guidelines
            _buildGuideTile(
              title: "What to do after a crash",
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.emergencyAmber,
              children: [
                _buildBulletPoint("1. Secure the Scene", "Park your vehicle in a safe spot, turn on hazard warning lights, and wear a high-visibility vest if available."),
                _buildBulletPoint("2. Assess Hazards", "Check for fuel leaks, smoke, fire, or exposed high-voltage wiring (in electric vehicles) before approaching."),
                _buildBulletPoint("3. Check for Responses", "Gently tap victims on the shoulders and ask loudly: 'Are you okay?' to check levels of consciousness."),
                _buildBulletPoint("4. Alert Services", "Use RoadSOS to notify nearest ambulance and police networks with exact coordinates."),
              ],
            ),
            const SizedBox(height: 12),

            _buildGuideTile(
              title: "CPR Basics (Cardiopulmonary Resuscitation)",
              icon: Icons.favorite_rounded,
              iconColor: AppColors.emergencyRed,
              children: [
                _buildBulletPoint("1. Check Consciousness & Breathing", "If the victim is unresponsive and not breathing normally, start CPR immediately."),
                _buildBulletPoint("2. Chest Compressions", "Place both hands in the center of the chest. Push hard and fast at a rate of 100 to 120 compressions per minute (approx. 2 inches deep)."),
                _buildBulletPoint("3. Rescue Breaths (If Trained)", "Deliver 2 rescue breaths after every 30 chest compressions. Keep chest moving up and down."),
                _buildBulletPoint("4. Continuous Cycle", "Continue the 30:2 ratio of compressions to breaths until medical professionals arrive or the patient recovers."),
              ],
            ),
            const SizedBox(height: 12),

            _buildGuideTile(
              title: "Bleeding Control & Hemorrhage",
              icon: Icons.opacity_rounded,
              iconColor: AppColors.emergencyRed,
              children: [
                _buildBulletPoint("1. Direct Pressure", "Apply firm, continuous pressure directly over the wound using a clean cloth, sterile dressing, or gloved hand."),
                _buildBulletPoint("2. Elevate the Limb", "If possible, raise the injured limb above the level of the heart to slow down the arterial bleeding rate."),
                _buildBulletPoint("3. Turnstiles / Tourniquets", "For severe, life-threatening extremity bleeding, apply a tourniquet 2 inches above the wound. Never place directly on a joint."),
                _buildBulletPoint("4. Prevent Shock", "Keep the victim warm and lying flat with legs slightly elevated while waiting for responders."),
              ],
            ),
            const SizedBox(height: 12),

            _buildGuideTile(
              title: "Emergency Numbers India 🇮🇳",
              icon: Icons.phone_in_talk_rounded,
              iconColor: AppColors.infoBlue,
              children: [
                _buildPhoneDialRow("🚑  Ambulance", "108"),
                _buildPhoneDialRow("🚔  Police Hotline", "100"),
                _buildPhoneDialRow("🔥  Fire Brigade", "101"),
                _buildPhoneDialRow("📞  National Emergency", "112"),
              ],
            ),
            const SizedBox(height: 12),

            _buildGuideTile(
              title: "Critical Dos and Don'ts",
              icon: Icons.rule_rounded,
              iconColor: AppColors.safeGreen,
              children: [
                _buildBulletPoint("DO: Keep Calm", "Panic hinders decision making. Speak slowly to victims to reassure them."),
                _buildBulletPoint("DO: Keep Neck Aligned", "Assume spinal injury. Avoid moving the victim's head unless there is an immediate fire hazard."),
                _buildBulletPoint("DON'T: Give Fluids", "Do not give food, water, or oral medications to an unconscious or heavily injured victim (risk of choking)."),
                _buildBulletPoint("DON'T: Remove Embedded Objects", "Do not pull out objects (knives, glass shards) embedded in the body. Secure them with dressings to prevent further tissue tearing."),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: iconColor, size: 24),
          title: Text(
            title,
            style: AppTypography.headlineMedium.copyWith(fontSize: 15, color: Colors.white),
          ),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textMuted,
          childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
          children: children,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String boldPart, String normalPart) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle_rounded, size: 6, color: AppColors.emergencyRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                children: [
                  TextSpan(
                    text: "$boldPart: ",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: normalPart),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneDialRow(String title, String number) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () async {
              final Uri telUri = Uri(scheme: 'tel', path: number);
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              }
            },
            icon: const Icon(Icons.call_rounded, size: 14, color: Colors.white),
            label: Text(
              number,
              style: AppTypography.monoMedium.copyWith(fontSize: 12, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}
