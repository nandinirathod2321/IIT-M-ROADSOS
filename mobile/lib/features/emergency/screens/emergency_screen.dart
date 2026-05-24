import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/hospital.dart';
import '../../../data/models/police_station.dart';
import '../../../data/models/towing_service.dart';
import '../../../data/models/emergency_contact.dart';

/// Full-production interactive Emergency Services and Contact management screen.
/// Switch dynamically between category chips: Hospitals, Police, Towing, and Contacts.
/// Automatically queries live GPS coordinates to match and sort local Ahmedabad & India services.
class EmergencyScreen extends StatefulWidget {
  final int initialSection;
  const EmergencyScreen({super.key, this.initialSection = 0});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  late int _selectedTab;
  
  bool _isLoading = true;
  double? _latitude;
  double? _longitude;
  String _gpsError = '';

  List<Hospital> _hospitals = [];
  List<PoliceStation> _police = [];
  List<TowingService> _towing = [];
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialSection;
    _resolveLocationAndData();
  }

  /// Fetches real coordinates via Geolocator and queries spatial SQLite lists
  Future<void> _resolveLocationAndData() async {
    setState(() {
      _isLoading = true;
      _gpsError = '';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsError = 'GPS services are disabled.';
        await _loadOfflineFallbackData(23.0225, 72.5714);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _gpsError = 'Location permission denied.';
        await _loadOfflineFallbackData(23.0225, 72.5714);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      _latitude = pos.latitude;
      _longitude = pos.longitude;
      await _loadOfflineFallbackData(pos.latitude, pos.longitude);

    } catch (e) {
      _gpsError = 'Failed to fetch GPS coordinates.';
      await _loadOfflineFallbackData(23.0225, 72.5714);
    }
  }

  /// Loads details matching coordinate locations
  Future<void> _loadOfflineFallbackData(double lat, double lng) async {
    try {
      final hospitalsList = await _db.getNearbyHospitals(lat, lng);
      final policeList = await _db.getNearbyPolice(lat, lng);
      final towingList = await _db.getNearbyTowing(lat, lng);
      final contactsList = await _db.getEmergencyContacts();

      setState(() {
        _hospitals = hospitalsList;
        _police = policeList;
        _towing = towingList;
        _contacts = contactsList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  /// Triggers standard hotline dialer via tel scheme
  Future<void> _makeCall(String phone) async {
    if (phone.isEmpty) return;
    final Uri url = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not dial';
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Dialing emergency number: $phone", style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.infoBlue,
        ),
      );
    }
  }

  /// Launches exact coordinates directions map query on Google Maps
  Future<void> _launchMap(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to open default system map navigation"),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  // ── Contact CRUD Dialogue Handlers ─────────────────────────────────────

  /// Opens the Add/Edit emergency contact modal sheet
  void _showContactFormDialog([EmergencyContact? contact]) {
    final isEditing = contact != null;
    final formKey = GlobalKey<FormState>();

    final nameCtrl = TextEditingController(text: isEditing ? contact.name : '');
    final phoneCtrl = TextEditingController(text: isEditing ? contact.phone : '');
    final emailCtrl = TextEditingController(text: isEditing ? contact.email : '');
    final relationCtrl = TextEditingController(text: isEditing ? contact.relationship : 'Family');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
          ),
          title: Text(
            isEditing ? "EDIT CONTACT" : "ADD EMERGENCY CONTACT",
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration("Full Name", Icons.person_outline_rounded),
                    validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: _dialogInputDecoration("Phone Number", Icons.phone_android_rounded),
                    validator: (v) => v == null || v.trim().isEmpty ? "Phone number is required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dialogInputDecoration("Email Address", Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Email is required";
                      final emailReg = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailReg.hasMatch(v.trim())) return "Enter a valid email address";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: relationCtrl.text,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration("Relationship", Icons.people_outline_rounded),
                    items: ["Family", "Friend", "Spouse", "Doctor", "Work", "Other"]
                        .map((rel) => DropdownMenuItem(value: rel, child: Text(rel)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) relationCtrl.text = val;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "CANCEL",
                style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final newContact = EmergencyContact(
                  id: isEditing ? contact.id : const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  relationship: relationCtrl.text,
                  avatarEmoji: _avatarForRelationship(relationCtrl.text),
                  isPrimary: isEditing ? contact.isPrimary : _contacts.isEmpty,
                );

                await _db.upsertEmergencyContact(newContact);
                Navigator.pop(context);

                _resolveLocationAndData(); // Refresh list
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
              ),
              child: Text(
                isEditing ? "SAVE" : "ADD",
                style: AppTypography.labelCaps.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Triggers standard contact deletion
  void _confirmDeleteContact(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: Text(
            "DELETE CONTACT",
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          content: Text(
            "Are you sure you want to delete ${contact.name} from your emergency contacts list?",
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL", style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _db.deleteEmergencyContact(contact.id);
                Navigator.pop(context);
                _resolveLocationAndData(); // Refresh list
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
              child: Text("DELETE", style: AppTypography.labelCaps.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      filled: true,
      fillColor: AppColors.surfaceAlt,
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
    );
  }

  String _avatarForRelationship(String relationship) {
    switch (relationship) {
      case 'Spouse':
        return '❤️';
      case 'Family':
        return '👨‍👩‍👦';
      case 'Friend':
        return '🤝';
      case 'Doctor':
        return '🩺';
      case 'Work':
        return '💼';
      default:
        return '👤';
    }
  }

  // ── Layout Builders ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          "EMERGENCY RESPONDERS",
          style: AppTypography.headlineLarge.copyWith(letterSpacing: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Horizontal tab navigation chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip(0, "Hospitals", Icons.emergency_rounded),
                  _buildTabChip(1, "Police", Icons.local_police_rounded),
                  _buildTabChip(2, "Towing", Icons.local_shipping_rounded),
                  _buildTabChip(3, "Contacts", Icons.people_outline_rounded),
                ],
              ),
            ),
          ),

          // GPS warning banner if offline or location permissions missing
          if (_gpsError.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.emergencyAmber.withOpacity(0.12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.emergencyAmber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$_gpsError Displaying default offline emergency database.",
                      style: AppTypography.bodySmall.copyWith(color: AppColors.emergencyAmber),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Main Tab View Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emergencyRed))
                : _buildSelectedTabContent(),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 3
          ? FloatingActionButton(
              onPressed: () => _showContactFormDialog(),
              backgroundColor: AppColors.emergencyRed,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabChip(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emergencyRed : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.emergencyRed : AppColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildHospitalsTab();
      case 1:
        return _buildPoliceTab();
      case 2:
        return _buildTowingTab();
      case 3:
        return _buildContactsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHospitalsTab() {
    if (_hospitals.isEmpty) {
      return _buildEmptyState("NO HOSPITALS FOUND", "No emergency medical facilities nearby.");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final item = _hospitals[index];
        return _buildServiceCard(
          name: item.name,
          address: item.address,
          badgeText: item.type == HospitalType.trauma ? "Level 1 Trauma" : "General Hospital",
          distance: "${item.distanceKm.toStringAsFixed(1)} km away",
          eta: "${item.estimatedMinutes.toStringAsFixed(1)} MINS ETA",
          phone: item.phone,
          lat: item.lat,
          lng: item.lng,
          accentColor: AppColors.emergencyRed,
        );
      },
    );
  }

  Widget _buildPoliceTab() {
    if (_police.isEmpty) {
      return _buildEmptyState("NO POLICE STATIONS FOUND", "No local jurisdictions mapped nearby.");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _police.length,
      itemBuilder: (context, index) {
        final item = _police[index];
        return _buildServiceCard(
          name: item.name,
          address: item.address,
          badgeText: item.is24Hours ? "24 Hours Active" : "Patrol Station",
          distance: "${item.distanceKm.toStringAsFixed(1)} km away",
          eta: "${(item.distanceKm * 2.2).toStringAsFixed(1)} MINS ETA",
          phone: item.phone,
          lat: item.lat,
          lng: item.lng,
          accentColor: AppColors.policeBlue,
        );
      },
    );
  }

  Widget _buildTowingTab() {
    if (_towing.isEmpty) {
      return _buildEmptyState("NO TOWING SERVICES FOUND", "No crane providers found in this radius.");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _towing.length,
      itemBuilder: (context, index) {
        final item = _towing[index];
        return _buildServiceCard(
          name: item.name,
          address: "Radius: ${item.serviceRadius.toStringAsFixed(0)} km · Hours: ${item.operatingHours}",
          badgeText: "Vehicle: ${item.vehicleTypes}",
          distance: "${item.distanceKm.toStringAsFixed(1)} km away",
          eta: "${(item.distanceKm * 2.5).toStringAsFixed(1)} MINS ETA",
          phone: item.phone,
          lat: item.lat,
          lng: item.lng,
          accentColor: AppColors.towingOrange,
        );
      },
    );
  }

  Widget _buildContactsTab() {
    if (_contacts.isEmpty) {
      return _buildEmptyState(
        "NO EMERGENCY CONTACTS SAVED",
        "Add emergency contacts who should be automatically notified during a critical SOS event.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final item = _contacts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceAlt,
                child: Text(
                  item.avatarEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.name,
                          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (item.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "PRIMARY",
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 8,
                                color: AppColors.emergencyRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Relation: ${item.relationship} · Phone: ${item.phone}",
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Email: ${item.email}",
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppColors.safeGreen, size: 20),
                    onPressed: () => _makeCall(item.phone),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showContactFormDialog(item),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.emergencyRed, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteContact(item),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String name,
    required String address,
    required String badgeText,
    required String distance,
    required String eta,
    required String phone,
    required double lat,
    required double lng,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText.toUpperCase(),
                        style: AppTypography.labelCaps.copyWith(color: accentColor, fontSize: 8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: AppTypography.headlineMedium.copyWith(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const Divider(color: AppColors.borderSubtle, height: 24, thickness: 1),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eta,
                    style: AppTypography.monoMedium.copyWith(
                      color: AppColors.safeGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance,
                    style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _launchMap(lat, lng),
                icon: const Icon(Icons.map_rounded, size: 12, color: Colors.white),
                label: Text(
                  "MAP",
                  style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 9),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceAlt,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: AppColors.borderSubtle, width: 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _makeCall(phone),
                icon: const Icon(Icons.phone_rounded, size: 12, color: Colors.white),
                label: Text(
                  "CALL",
                  style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 9),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
