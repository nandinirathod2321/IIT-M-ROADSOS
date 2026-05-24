import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/medical_profile.dart';

/// Complete, production-grade Medical ID screen for paramedics and first responders.
/// Displays an emergency medical card, secure local QR code module, and permits full profile editing.
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
  String _errorMsg = '';

  // Form Controllers — Initialized immediately to prevent late-variable runtime exceptions
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _conditionsController;
  late TextEditingController _contactController;
  
  String _selectedBloodGroup = "O+";
  String _selectedGender = "Male";
  bool _isOrganDonor = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _allergiesController = TextEditingController();
    _medicationsController = TextEditingController();
    _conditionsController = TextEditingController();
    _contactController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _conditionsController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  /// Loads the medical profile from SQLite, initializing demo values if empty.
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      // Ensure database is initialized
      await _db.initialize();
      
      MedicalProfile? profile = await _db.getMedicalProfile('me');
      
      if (profile == null) {
        profile = const MedicalProfile(
          userId: 'me',
          fullName: 'Nandini Rathod',
          age: 21,
          gender: 'Female',
          bloodGroup: 'O+',
          allergies: ['Penicillin', 'Peanuts'],
          medications: ['None'],
          conditions: ['None'],
          emergencyContactId: '+91 98765 43210',
          organDonor: true,
        );
        await _db.upsertMedicalProfile(profile);
      }

      _nameController.text = profile.fullName;
      _ageController.text = profile.age > 0 ? profile.age.toString() : '';
      _allergiesController.text = profile.allergies.join(', ');
      _medicationsController.text = profile.medications.join(', ');
      _conditionsController.text = profile.conditions.join(', ');
      _contactController.text = profile.emergencyContactId;
      _selectedBloodGroup = _bloodGroupsList.contains(profile.bloodGroup) ? profile.bloodGroup : "O+";
      _selectedGender = _gendersList.contains(profile.gender) ? profile.gender : "Female";
      _isOrganDonor = profile.organDonor;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to load Medical ID database: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Persists edits locally in SQLite database.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = MedicalProfile(
        userId: 'me',
        fullName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        gender: _selectedGender,
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
        conditions: _conditionsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
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
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: ${e.toString()}'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  /// Shares the pre-formatted Medical ID via share tray
  void _shareMedicalId() {
    if (_profile == null) return;
    final p = _profile!;
    final summary = 
        "🚑 RoadSOS Emergency Medical ID:\n"
        "---------------------------------\n"
        "Full Name: ${p.fullName}\n"
        "Age: ${p.age > 0 ? p.age : 'Unspecified'}\n"
        "Gender: ${p.gender.isNotEmpty ? p.gender : 'Unspecified'}\n"
        "Blood Group: ${p.bloodGroup}\n"
        "Allergies: ${p.allergies.isNotEmpty ? p.allergies.join(', ') : 'None'}\n"
        "Current Medications: ${p.medications.isNotEmpty ? p.medications.join(', ') : 'None'}\n"
        "Medical Conditions: ${p.conditions.isNotEmpty ? p.conditions.join(', ') : 'None'}\n"
        "Emergency Contact: ${p.emergencyContactId}\n"
        "Organ Donor: ${p.organDonor ? 'Yes' : 'No'}";

    Share.share(summary, subject: "RoadSOS Emergency Medical ID");
  }

  final List<String> _bloodGroupsList = const ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
  final List<String> _gendersList = const ["Male", "Female", "Other"];

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

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.emergencyRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMsg,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text("RETRY LOADING"),
                ),
              ],
            ),
          ),
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
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: _shareMedicalId,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Revert form fields
                  _nameController.text = _profile!.fullName;
                  _ageController.text = _profile!.age > 0 ? _profile!.age.toString() : '';
                  _allergiesController.text = _profile!.allergies.join(', ');
                  _medicationsController.text = _profile!.medications.join(', ');
                  _conditionsController.text = _profile!.conditions.join(', ');
                  _contactController.text = _profile!.emergencyContactId;
                  _selectedBloodGroup = _profile!.bloodGroup;
                  _selectedGender = _profile!.gender;
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

  /// Renders paramedic-readable clean layout
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
                    "FIRST-RESPONDER MEDICAL DATA",
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

                // Parametric demographics row: Age & Gender
                Row(
                  children: [
                    Expanded(
                      child: _buildBadgeCell(
                        "AGE",
                        profile.age > 0 ? "${profile.age} Yrs" : "--",
                        Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildBadgeCell(
                        "GENDER",
                        profile.gender.isNotEmpty ? profile.gender.toUpperCase() : "--",
                        Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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

                // Conditions list
                _buildInfoSection(
                  "MEDICAL CONDITIONS",
                  profile.conditions.isNotEmpty ? profile.conditions.join(", ") : "None",
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

          // Secure QR Module
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
                  "First responders scan this module on lock screen",
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
              fontSize: 20,
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

  /// Renders edit inputs with proper validations
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
              validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _ageController,
                    label: "Age",
                    icon: Icons.calendar_month_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Age required";
                      final ageVal = int.tryParse(v.trim());
                      if (ageVal == null || ageVal <= 0) return "Must be positive";
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildGenderDropdown()),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            _buildInputField(
              controller: _medicationsController,
              label: "Current Medications",
              icon: Icons.healing_outlined,
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _conditionsController,
              label: "Medical Conditions",
              icon: Icons.health_and_safety_outlined,
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _contactController,
              label: "Emergency Phone Number",
              icon: Icons.phone_android_rounded,
              validator: (v) => v == null || v.trim().isEmpty ? "Phone number is required" : null,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: AppTypography.bodyLarge.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
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
        borderRadius: BorderRadius.circular(6),
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
            prefixIcon: const Icon(Icons.water_drop_rounded, color: AppColors.emergencyRed, size: 18),
            border: InputBorder.none,
          ),
          items: _bloodGroupsList
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

  Widget _buildGenderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedGender,
          dropdownColor: AppColors.surface,
          style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Gender",
            labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.wc_rounded, color: AppColors.textMuted, size: 18),
            border: InputBorder.none,
          ),
          items: _gendersList
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedGender = val);
            }
          },
        ),
      ),
    );
  }
}
