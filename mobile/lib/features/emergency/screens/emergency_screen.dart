import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../presentation/blocs/location/location_cubit.dart';
import '../../../presentation/blocs/location/location_state.dart';
import '../../../core/responders/responder_cubit.dart';
import '../../../core/responders/responder_state.dart';
import '../../../data/repositories/emergency_contact_repository.dart';
import '../../../data/models/hospital.dart';
import '../../../data/models/police_station.dart';
import '../../../data/models/towing_service.dart';
import '../../../data/models/emergency_contact.dart';
import '../../../data/models/emergency_shelter.dart';
import '../../../shared/widgets/responder_error_widget.dart';
import 'nearby_map_screen.dart';

/// Full-production interactive Emergency Services and Contact management screen.
/// Consumes data from the shared [ResponderCubit] and [LocationCubit] — no
/// duplicate GPS fetches or API calls vs. the Home screen.
class EmergencyScreen extends StatefulWidget {
  final int initialSection;
  const EmergencyScreen({super.key, this.initialSection = 0});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final EmergencyContactRepository _contactsRepo = EmergencyContactRepository();
  late int _selectedTab;
  List<EmergencyContact> _contacts = [];
  bool _contactsLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialSection;
    _loadContacts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LocationCubit>().initLocation();
      }
    });
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _contactsRepo.getContacts();
      if (mounted) {
        debugPrint("[AntiGravity] Contacts fetched successfully: ${contacts.length} entries");
        setState(() {
          _contacts = contacts;
          _contactsLoading = false;
        });
        debugPrint("[AntiGravity] State updated via setState for contacts.");
      }
    } catch (e) {
      debugPrint("[AntiGravity] Error caught in _loadContacts: $e");
      if (mounted) setState(() => _contactsLoading = false);
    }
  }

  // ── Diallers ────────────────────────────────────────────────────────────

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Dialing: $phone", style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.infoBlue,
          ),
        );
      }
    }
  }

  Future<void> _launchMap(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ── Contact CRUD ─────────────────────────────────────────────────────────

  void _showContactFormDialog([EmergencyContact? contact]) {
    final isEditing = contact != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: isEditing ? contact.name : '');
    final phoneCtrl = TextEditingController(text: isEditing ? contact.phone : '');
    final emailCtrl = TextEditingController(text: isEditing ? contact.email : '');
    final relationCtrl = TextEditingController(text: isEditing ? contact.relationship : 'Family');
    bool isPrimaryVal = isEditing ? contact.isPrimary : _contacts.isEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
              ),
              title: Text(
                isEditing ? "EDIT CONTACT" : "ADD EMERGENCY CONTACT",
                style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
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
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDeco("Full Name", Icons.person_outline_rounded),
                        validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco("Phone Number", Icons.phone_android_rounded),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Phone number is required";
                          final reg = RegExp(r'^\+?[0-9\s\-]{10,15}$');
                          if (!reg.hasMatch(v.trim())) return "Enter a valid phone number (min 10 digits)";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco("Email Address", Icons.email_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Email is required";
                          final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (!reg.hasMatch(v.trim())) return "Enter a valid email address";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: relationCtrl.text,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDeco("Relationship", Icons.people_outline_rounded),
                        items: ["Family", "Friend", "Spouse", "Doctor", "Work", "Other"]
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => relationCtrl.text = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text("Mark as Primary Contact",
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                        subtitle: Text("Prioritized for SOS alerts",
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        value: isPrimaryVal,
                        activeThumbColor: AppColors.safeGreen,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => isPrimaryVal = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteContact(contact);
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.emergencyRed),
                    child: Text("DELETE",
                        style: AppTypography.labelCaps.copyWith(color: AppColors.emergencyRed)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("CANCEL",
                      style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary)),
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
                      avatarEmoji: _avatarFor(relationCtrl.text),
                      isPrimary: isPrimaryVal,
                    );
                    await _contactsRepo.saveContact(newContact);
                    if (context.mounted) Navigator.pop(context);
                    _loadContacts();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
                  child: Text(isEditing ? "SAVE" : "ADD",
                      style: AppTypography.labelCaps.copyWith(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteContact(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.borderSubtle)),
        title: Text("DELETE CONTACT",
            style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary)),
        content: Text(
            "Are you sure you want to delete ${contact.name} from your emergency contacts?",
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL",
                  style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              await _contactsRepo.deleteContact(contact.id);
              if (context.mounted) Navigator.pop(context);
              _loadContacts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
            child:
                Text("DELETE", style: AppTypography.labelCaps.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.borderSubtle)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.borderSubtle)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.emergencyRed)),
      );

  String _avatarFor(String rel) {
    switch (rel) {
      case 'Spouse': return '❤️';
      case 'Family': return '👨‍👩‍👦';
      case 'Friend': return '🤝';
      case 'Doctor': return '🩺';
      case 'Work':   return '💼';
      default:       return '👤';
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResponderCubit, ResponderState>(
      builder: (context, responderState) {
        final totalEntries = responderState.hospitals.length +
            responderState.police.length +
            responderState.towing.length +
            responderState.shelters.length;
        debugPrint("[AntiGravity] Widget rebuilding with data: $totalEntries entries");

        final locState = context.watch<LocationCubit>().state;
        final bool gpsAvailable = locState.hasLocation;
        final bool gpsLoading = locState.status == LocationStatus.loading ||
            locState.status == LocationStatus.initial;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            title: Text("EMERGENCY RESPONDERS",
                style: AppTypography.headlineLarge.copyWith(letterSpacing: 0.5)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                tooltip: "Force Refresh",
                onPressed: () {
                  debugPrint('[EmergencyScreen] Manual refresh triggered.');
                  context.read<ResponderCubit>().forceRefresh();
                },
              ),
            ],
            backgroundColor: AppColors.surface,
            elevation: 0,
          ),
          body: Column(
            children: [
              // ── Offline banner ──────────────────────────────────────
              if (responderState.isOffline)
                _infoBanner(
                  Icons.wifi_off_rounded,
                  "Offline Mode — showing cached emergency data.",
                  AppColors.infoBlue,
                ),

              // ── Cache banner ────────────────────────────────────────
              if (responderState.isFromCache && !responderState.isOffline && responderState.hasData)
                _infoBanner(
                  Icons.cached_rounded,
                  "Showing locally cached data. Pull refresh for live results.",
                  AppColors.emergencyAmber,
                ),

              // ── Tab chips ───────────────────────────────────────────
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
                      _tabChip(0, "Hospitals", Icons.emergency_rounded,
                          responderState.hospitals.length),
                      _tabChip(1, "Police", Icons.local_police_rounded,
                          responderState.police.length),
                      _tabChip(2, "Towing", Icons.local_shipping_rounded,
                          responderState.towing.length),
                      _tabChip(3, "Shelters", Icons.home_work_rounded,
                          responderState.shelters.length),
                      _tabChip(4, "Contacts", Icons.people_outline_rounded,
                          _contacts.length),
                      _tabChip(5, "Map", Icons.map_rounded, 0),
                    ],
                  ),
                ),
              ),

              // ── Main content ────────────────────────────────────────
              Expanded(
                child: _buildBody(
                  responderState: responderState,
                  gpsAvailable: gpsAvailable,
                  gpsLoading: gpsLoading,
                  locState: locState,
                ),
              ),
            ],
          ),
          floatingActionButton: _selectedTab == 4
              ? FloatingActionButton(
                  onPressed: () => _showContactFormDialog(),
                  backgroundColor: AppColors.emergencyRed,
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody({
    required ResponderState responderState,
    required bool gpsAvailable,
    required bool gpsLoading,
    required LocationState locState,
  }) {
    // GPS not yet available
    if (!gpsAvailable) {
      if (gpsLoading) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.emergencyRed),
              SizedBox(height: 16),
              Text("RESOLVING GPS...",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  )),
            ],
          ),
        );
      }
      // GPS denied/failed
      return ResponderErrorWidget(
        type: ResponderErrorType.gpsDenied,
        customMessage: locState.errorMessage.isNotEmpty ? locState.errorMessage : null,
        onRetry: () => context.read<LocationCubit>().initLocation(),
        retryLabel: 'RETRY GPS',
      );
    }

    // GPS available but responders loading
    if (responderState.isLoading && !responderState.hasData) {
      return const _ShimmerList();
    }

    // Error state and no cache
    if (responderState.hasFailed && !responderState.hasData) {
      final type = responderState.isOffline
          ? ResponderErrorType.noInternet
          : ResponderErrorType.apiUnavailable;
      return ResponderErrorWidget(
        type: type,
        customMessage: responderState.errorMessage.isNotEmpty ? responderState.errorMessage : null,
        onRetry: () => context.read<ResponderCubit>().retry(),
        retryLabel: 'RETRY',
      );
    }

    // Data available — show tabs
    return _buildSelectedTab(responderState);
  }

  Widget _buildSelectedTab(ResponderState rs) {
    switch (_selectedTab) {
      case 0: return _buildHospitalsTab(rs.hospitals);
      case 1: return _buildPoliceTab(rs.police);
      case 2: return _buildTowingTab(rs.towing);
      case 3: return _buildSheltersTab(rs.shelters);
      case 4: return _buildContactsTab();
      case 5: return const NearbyMapView();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildHospitalsTab(List<Hospital> hospitals) {
    if (hospitals.isEmpty) {
      return ResponderErrorWidget(
        type: ResponderErrorType.empty,
        customMessage: "No hospitals found within the search radius.",
        onRetry: () => context.read<ResponderCubit>().retry(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hospitals.length,
      itemBuilder: (context, i) {
        final h = hospitals[i];
        return _serviceCard(
          name: h.name,
          address: h.address,
          badgeText: h.type == HospitalType.trauma ? "Level 1 Trauma" : "General Hospital",
          distance: "${h.distanceKm.toStringAsFixed(1)} km away",
          eta: "${h.estimatedMinutes.toStringAsFixed(1)} MINS ETA",
          phone: h.phone,
          lat: h.lat,
          lng: h.lng,
          accentColor: AppColors.emergencyRed,
        );
      },
    );
  }

  Widget _buildPoliceTab(List<PoliceStation> police) {
    if (police.isEmpty) {
      return ResponderErrorWidget(
        type: ResponderErrorType.empty,
        customMessage: "No police stations found within the search radius.",
        onRetry: () => context.read<ResponderCubit>().retry(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: police.length,
      itemBuilder: (context, i) {
        final p = police[i];
        return _serviceCard(
          name: p.name,
          address: p.address,
          badgeText: p.is24Hours ? "24 Hours Active" : "Patrol Station",
          distance: "${p.distanceKm.toStringAsFixed(1)} km away",
          eta: "${(p.distanceKm * 2.2).toStringAsFixed(1)} MINS ETA",
          phone: p.phone,
          lat: p.lat,
          lng: p.lng,
          accentColor: AppColors.policeBlue,
        );
      },
    );
  }

  Widget _buildTowingTab(List<TowingService> towing) {
    if (towing.isEmpty) {
      return ResponderErrorWidget(
        type: ResponderErrorType.empty,
        customMessage: "No towing services found in this area.",
        onRetry: () => context.read<ResponderCubit>().retry(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: towing.length,
      itemBuilder: (context, i) {
        final t = towing[i];
        return _serviceCard(
          name: t.name,
          address: "Radius: ${t.serviceRadius.toStringAsFixed(0)} km · Hours: ${t.operatingHours}",
          badgeText: "Vehicle: ${t.vehicleTypes}",
          distance: "${t.distanceKm.toStringAsFixed(1)} km away",
          eta: "${(t.distanceKm * 2.5).toStringAsFixed(1)} MINS ETA",
          phone: t.phone,
          lat: t.lat,
          lng: t.lng,
          accentColor: AppColors.towingOrange,
        );
      },
    );
  }

  Widget _buildSheltersTab(List<EmergencyShelter> shelters) {
    if (shelters.isEmpty) {
      return ResponderErrorWidget(
        type: ResponderErrorType.empty,
        customMessage: "No community shelters mapped nearby.",
        onRetry: () => context.read<ResponderCubit>().retry(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: shelters.length,
      itemBuilder: (context, i) {
        final s = shelters[i];
        return _serviceCard(
          name: s.name,
          address: s.address,
          badgeText: "Capacity: ${s.capacity} people",
          distance: "${s.distanceKm.toStringAsFixed(1)} km away",
          eta: "${(s.distanceKm * 2.0).toStringAsFixed(1)} MINS ETA",
          phone: s.phone,
          lat: s.lat,
          lng: s.lng,
          accentColor: AppColors.safeGreen,
        );
      },
    );
  }

  Widget _buildContactsTab() {
    if (_contactsLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.emergencyRed));
    }
    if (_contacts.isEmpty) {
      return ResponderErrorWidget(
        type: ResponderErrorType.empty,
        customMessage:
            "Add emergency contacts who will be notified automatically during a critical SOS event.",
        onRetry: () => _showContactFormDialog(),
        retryLabel: 'ADD CONTACT',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      itemBuilder: (context, i) {
        final c = _contacts[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceAlt,
                child: Text(c.avatarEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.name,
                            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                        if (c.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text("PRIMARY",
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 8,
                                  color: AppColors.emergencyRed,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("${c.relationship} · ${c.phone}",
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(c.email,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppColors.safeGreen, size: 20),
                    onPressed: () => _makeCall(c.phone),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showContactFormDialog(c),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.emergencyRed, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteContact(c),
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

  // ── Helpers ─────────────────────────────────────────────────────────────


  Widget _tabChip(int index, String label, IconData icon, int count) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emergencyRed : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.emergencyRed : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBanner(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTypography.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard({
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
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText.toUpperCase(),
                        style: AppTypography.labelCaps.copyWith(color: accentColor, fontSize: 8),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(name,
                        style: AppTypography.headlineMedium.copyWith(
                            fontSize: 18, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(address,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
          const Divider(color: AppColors.borderSubtle, height: 24, thickness: 1),
          Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(eta,
                        style: AppTypography.monoMedium.copyWith(
                          color: AppColors.safeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(distance,
                        style: AppTypography.bodySmall
                            .copyWith(fontSize: 10, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _launchMap(lat, lng),
                icon: const Icon(Icons.map_rounded, size: 12, color: AppColors.textPrimary),
                label: Text("MAP",
                    style: AppTypography.labelCaps.copyWith(color: AppColors.textPrimary, fontSize: 9)),
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
                label: Text("CALL",
                    style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 9)),
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

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceAlt,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
