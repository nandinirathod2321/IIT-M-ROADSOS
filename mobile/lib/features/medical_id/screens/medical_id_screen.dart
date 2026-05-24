import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/medical_profile.dart';

/// Full-featured Medical ID screen for first responders.
/// Displays a premium emergency responder card, editable profile fields,
/// and a dynamically generated local secure QR code.
class MedicalIdScreen extends StatefulWidget {
  const MedicalIdScreen({super.key});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  bool _isEditing = false;
  MedicalProfile? _profile;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _contactController;
  String _selectedBloodGroup = "O+";
  bool _isOrganDonor = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  /// Loads the medical profile from SQLite, initializing demo values if empty.
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    // Ensure DB is initialized
    await _db.initialize();
    
    MedicalProfile? profile = await _db.getMedicalProfile('me');
    
    if (profile == null) {
      // Prefilled high-fidelity Ahmedabad hackathon demo profile data
      profile = const MedicalProfile(
        userId: 'me',
        fullName: 'Nandini Rathod',
        bloodGroup: 'O+',
        allergies: ['Penicillin', 'Peanuts'],
        medications: ['None'],
        conditions: ['None'],
        emergencyContactId: '+91 98765 43210',
        organDonor: true,
      );
      await _db.upsertMedicalProfile(profile);
    }

    _nameController = TextEditingController(text: profile.fullName);
    _allergiesController = TextEditingController(text: profile.allergies.join(', '));
    _medicationsController = TextEditingController(text: profile.medications.join(', '));
    _contactController = TextEditingController(text: profile.emergencyContactId);
    _selectedBloodGroup = profile.bloodGroup.isNotEmpty ? profile.bloodGroup : "O+";
    _isOrganDonor = profile.organDonor;

    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  /// Persists edits locally in SQLite database.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updatedProfile = MedicalProfile(
      userId: 'me',
      fullName: _nameController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      allergies: _allergiesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      medications: _medicationsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      conditions: const ['None'],
      emergencyContactId: _contactController.text.trim(),
      organDonor: _isOrganDonor,
    );

    await _db.upsertMedicalProfile(updatedProfile);
    
    setState(() {
      _profile = updatedProfile;
      _isEditing = false;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Medical ID profile saved successfully',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.safeGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.emergencyRed),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'EDIT MEDICAL ID' : 'MEDICAL ID',
          style: AppTypography.headlineLarge.copyWith(letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded),
            color: AppColors.textSecondary,
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Revert form fields to saved profile
                  _nameController.text = _profile!.fullName;
                  _allergiesController.text = _profile!.allergies.join(', ');
                  _medicationsController.text = _profile!.medications.join(', ');
                  _contactController.text = _profile!.emergencyContactId;
                  _selectedBloodGroup = _profile!.bloodGroup;
                  _isOrganDonor = _profile!.organDonor;
                }
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildProfileView(),
    );
  }

  /// Renders the premium paramedic-readable medical card and QR code.
  Widget _buildProfileView() {
    final profile = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paramedic warning banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.emergencyRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.emergencyRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_services_rounded, color: AppColors.emergencyRed),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "FIRST-RESPONDER INFORMATION",
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.emergencyRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Medical ID Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Circle
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          "👤",
                          style: TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: AppTypography.headlineMedium.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Emergency Profile ID: #092811",
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Critical Row: Blood type & Organ Donor
                Row(
                  children: [
                    Expanded(
                      child: _buildBadgeCell(
                        "BLOOD GROUP",
                        profile.bloodGroup,
                        AppColors.emergencyRed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildBadgeCell(
                        "ORGAN DONOR",
                        profile.organDonor ? "YES" : "NO",
                        profile.organDonor ? AppColors.safeGreen : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Allergies list
                _buildInfoSection(
                  "ALLERGIES",
                  profile.allergies.isNotEmpty ? profile.allergies.join(", ") : "No Known Allergies",
                  profile.allergies.isNotEmpty ? AppColors.emergencyRed : AppColors.textSecondary,
                ),
                const SizedBox(height: 16),

                // Medications list
                _buildInfoSection(
                  "MEDICATIONS",
                  profile.medications.isNotEmpty ? profile.medications.join(", ") : "None",
                  Colors.white,
                ),
                const SizedBox(height: 16),

                // Emergency Contact details
                _buildInfoSection(
                  "EMERGENCY CONTACT",
                  profile.emergencyContactId,
                  Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code container for paramedic screen scans
          Center(
            child: Column(
              children: [
                Text(
                  "SECURE PARAMEDIC QR DATA",
                  style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: jsonEncode(profile.toSnapshot()),
                    version: QrVersions.auto,
                    size: 160.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Scan to import medical profile on lock screen",
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBadgeCell(String title, String val, Color highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelCaps.copyWith(fontSize: 9, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: AppTypography.headlineLarge.copyWith(
              color: highlight,
              fontSize: 24,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelCaps.copyWith(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: AppTypography.bodyLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Renders standard profile inputs with clean validations.
  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PERSONAL DATA",
              style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline_rounded,
              validator: (v) => v == null || v.trim().isEmpty ? "Name required" : null,
            ),
            const SizedBox(height: 16),
            _buildBloodGroupDropdown(),
            const SizedBox(height: 24),

            Text(
              "MEDICAL DETAILS",
              style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _allergiesController,
              label: "Allergies (comma separated)",
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _medicationsController,
              label: "Current Medications",
              icon: Icons.healing_outlined,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _contactController,
              label: "Emergency Phone Number",
              icon: Icons.phone_android_rounded,
              validator: (v) => v == null || v.trim().isEmpty ? "Phone required" : null,
            ),
            const SizedBox(height: 16),
            
            // Organ Donor toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_outline_rounded, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Organ Donor",
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                  Switch(
                    value: _isOrganDonor,
                    onChanged: (v) => setState(() => _isOrganDonor = v),
                    activeThumbColor: AppColors.safeGreen,
                    activeTrackColor: AppColors.safeGreen.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text(
                  "SAVE CHANGES",
                  style: AppTypography.labelCaps.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: AppTypography.bodyLarge.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.emergencyRed),
        ),
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedBloodGroup,
          dropdownColor: AppColors.surface,
          style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Blood Group",
            labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.water_drop_rounded, color: AppColors.emergencyRed),
            border: InputBorder.none,
          ),
          items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedBloodGroup = val);
            }
          },
        ),
      ),
    );
  }
}
