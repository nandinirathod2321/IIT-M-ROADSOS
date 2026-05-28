import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/repositories/medical_repository.dart';
import '../../../data/models/medical_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/logger.dart';

/// Renders a paramedic-readable Medical ID screen with QR code access
/// and safe emergency information inputs.
class MedicalIdScreen extends StatefulWidget {
  const MedicalIdScreen({super.key});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MedicalRepository();

  bool _isLoading = true;
  bool _isEditing = false;
  String _errorMsg = '';

  MedicalProfile? _profile;

  // Controllers for editing
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedBloodGroup = "O+";
  String _selectedGender = "Male";
  bool _isOrganDonor = false;

  @override
  void initState() {
    super.initState();
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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final currentUserId = AuthService.instance.currentUserId ?? 'me';
      final profile = await _repository.getMedicalProfile(currentUserId);
      if (profile != null) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.fullName;
          _ageController.text = profile.age > 0 ? profile.age.toString() : '';
          _allergiesController.text = profile.allergies.join(', ');
          _medicationsController.text = profile.medications.join(', ');
          _conditionsController.text = profile.conditions.join(', ');
          _contactController.text = profile.emergencyContactId;
          _notesController.text = profile.emergencyNotes;
          _selectedBloodGroup = profile.bloodGroup.isNotEmpty ? profile.bloodGroup : "O+";
          _selectedGender = profile.gender.isNotEmpty ? profile.gender : "Male";
          _isOrganDonor = profile.organDonor;
        });
      } else {
        // Seed an empty profile
        setState(() {
          _profile = MedicalProfile(
            userId: currentUserId,
            fullName: '',
            age: 0,
            bloodGroup: 'O+',
            gender: 'Male',
            allergies: const [],
            medications: const [],
            conditions: const [],
            emergencyContactId: '',
            emergencyNotes: '',
            organDonor: false,
          );
          _isEditing = true;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load medical ID profile', e);
      setState(() {
        _errorMsg = 'Could not load your Medical ID: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final currentUserId = AuthService.instance.currentUserId ?? 'me';
    final updated = MedicalProfile(
      userId: currentUserId,
      fullName: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      bloodGroup: _selectedBloodGroup,
      gender: _selectedGender,
      allergies: _allergiesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      medications: _medicationsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      conditions: _conditionsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      emergencyContactId: _contactController.text.trim(),
      emergencyNotes: _notesController.text.trim(),
      organDonor: _isOrganDonor,
    );

    try {
      await _repository.saveMedicalProfile(updated);
      setState(() {
        _profile = updated;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Medical ID profile saved successfully."),
            backgroundColor: AppColors.safeGreen,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save medical ID profile', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save profile: ${e.toString()}"),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareMedicalId() {
    if (_profile == null) return;
    final text = "RoadSOS Emergency Medical ID\n"
        "Name: ${_profile!.fullName}\n"
        "Blood Group: ${_profile!.bloodGroup}\n"
        "Emergency Contact: ${_profile!.emergencyContactId}\n"
        "Allergies: ${_profile!.allergies.join(', ')}\n"
        "Notes: ${_profile!.emergencyNotes}";
    SharePlus.instance.share(ShareParams(text: text));
  }

  final List<String> _bloodGroupsList = const ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
  final List<String> _gendersList = const ["Male", "Female", "Other"];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.emergencyRed),
        ),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
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
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'EDIT MEDICAL ID' : 'MEDICAL ID',
          style: AppTypography.headlineLarge.copyWith(color: AppColors.textPrimary, letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              onPressed: _shareMedicalId,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, color: AppColors.textPrimary),
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
                  _notesController.text = _profile!.emergencyNotes;
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
              color: AppColors.emergencyRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
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
                            profile.fullName.isNotEmpty ? profile.fullName : "Unknown Responder",
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.textPrimary,
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
                        AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildBadgeCell(
                        "GENDER",
                        profile.gender.isNotEmpty ? profile.gender.toUpperCase() : "--",
                        AppColors.textPrimary,
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
                  AppColors.textPrimary,
                ),
                const SizedBox(height: 16),

                // Conditions list
                _buildInfoSection(
                  "MEDICAL CONDITIONS",
                  profile.conditions.isNotEmpty ? profile.conditions.join(", ") : "None",
                  AppColors.textPrimary,
                ),
                const SizedBox(height: 16),

                // Emergency Contact details
                _buildInfoSection(
                  "EMERGENCY CONTACT",
                  profile.emergencyContactId,
                  AppColors.textPrimary,
                ),
                const SizedBox(height: 16),
                // Emergency Notes details
                _buildInfoSection(
                  "EMERGENCY NOTES",
                  profile.emergencyNotes.isNotEmpty ? profile.emergencyNotes : "None",
                  AppColors.textPrimary,
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
                    border: Border.all(color: AppColors.borderSubtle),
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
            const SizedBox(height: 12),
            _buildInputField(
              controller: _notesController,
              label: "Emergency Notes",
              icon: Icons.notes_rounded,
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
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  Switch(
                    value: _isOrganDonor,
                    onChanged: (v) => setState(() => _isOrganDonor = v),
                    activeThumbColor: AppColors.safeGreen,
                    activeTrackColor: AppColors.safeGreen.withValues(alpha: 0.3),
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
      style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
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
          initialValue: _selectedBloodGroup,
          dropdownColor: AppColors.surface,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "Blood Group",
            labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.water_drop_rounded, color: AppColors.emergencyRed, size: 18),
            border: InputBorder.none,
          ),
          items: _bloodGroupsList
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g, style: const TextStyle(color: AppColors.textPrimary)),
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
          initialValue: _selectedGender,
          dropdownColor: AppColors.surface,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "Gender",
            labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.wc_rounded, color: AppColors.textMuted, size: 18),
            border: InputBorder.none,
          ),
          items: _gendersList
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g, style: const TextStyle(color: AppColors.textPrimary)),
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
