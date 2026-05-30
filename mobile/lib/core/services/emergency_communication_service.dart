import 'dart:convert';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../data/repositories/emergency_contact_repository.dart';
import '../../data/repositories/medical_repository.dart';
import '../../data/repositories/nearby_services_repository.dart';
import '../utils/emergency_logger.dart';
import '../utils/geocoder_mobile.dart';

/// Payload structure representing all essential GPS and Medical ID telemetry.
class EmergencyPayload {
  final String userName;
  final double lat;
  final double lng;
  final String address;
  final String timestamp;
  final String emergencyType; // manual / crash-detected
  final String? medicalSummary;
  final List<String> notifiedContacts;

  EmergencyPayload({
    required this.userName,
    required this.lat,
    required this.lng,
    required this.address,
    required this.timestamp,
    required this.emergencyType,
    this.medicalSummary,
    required this.notifiedContacts,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'coordinates': {'lat': lat, 'lng': lng},
      'address': address,
      'timestamp': timestamp,
      'emergency_type': emergencyType,
      'medical_summary': medicalSummary,
      'notified_contacts': notifiedContacts,
    };
  }

  factory EmergencyPayload.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>? ?? {};
    return EmergencyPayload(
      userName: json['user_name'] as String? ?? 'User',
      lat: (coords['lat'] as num? ?? 0.0).toDouble(),
      lng: (coords['lng'] as num? ?? 0.0).toDouble(),
      address: json['address'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      emergencyType: json['emergency_type'] as String? ?? 'manual',
      medicalSummary: json['medical_summary'] as String?,
      notifiedContacts: List<String>.from(json['notified_contacts'] ?? []),
    );
  }
}

/// Service handling cellular dialer intent integrations.
class EmergencyCallService {
  Future<bool> call108() async {
    final prefs = await SharedPreferences.getInstance();
    final permCall = prefs.getBool('perm_call') ?? false;
    
    if (permCall) {
      final url = Uri.parse('tel:108');
      try {
        await EmergencyLogger.log("CALL_PHONE permission is true. Triggering auto-call to 108...");
        if (await canLaunchUrl(url)) {
          final success = await launchUrl(url);
          await EmergencyLogger.log("CALL_PHONE launched: $success");
          return success;
        } else {
          await EmergencyLogger.log("CALL_PHONE auto-call launcher failed.");
        }
      } catch (e) {
        await EmergencyLogger.log("Exception during auto-call dial: $e");
      }
    } else {
      await EmergencyLogger.log("CALL_PHONE permission is false/denied. Auto-call skipped.");
    }
    return false;
  }
}

/// Service handling bulk multi-recipient SMS dispatch alerts.
class EmergencySmsService {
  final EmergencyContactRepository _contactsRepo = EmergencyContactRepository();

  Future<int> sendToAllContacts(double lat, double lng, String userName, String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final permSms = prefs.getBool('perm_sms') ?? false;

    if (!permSms) {
      await EmergencyLogger.log("SEND_SMS permission is false/denied. SMS alerts skipped.");
      return 0;
    }

    final contacts = await _contactsRepo.getContacts();
    if (contacts.isEmpty) {
      await EmergencyLogger.log("No saved emergency contacts found. SMS skipped.");
      return 0;
    }

    int sentCount = 0;
    final List<Future<void>> futures = contacts.map((contact) async {
      final phoneNum = contact.phone.trim();
      if (phoneNum.isEmpty) {
        await EmergencyLogger.log("Contact ${contact.name} has no phone number. Skipped SMS.");
        return;
      }

      final body = "RoadSOS Emergency Alert. $userName may need immediate help. Location: https://maps.google.com/?q=$lat,$lng — Sent at $timestamp. Please contact them immediately.";
      try {
        await EmergencyLogger.log("Sending SMS alert to ${contact.name} ($phoneNum)...");
        await sendSMS(message: body, recipients: [phoneNum]);
        sentCount++;
        await EmergencyLogger.log("SMS alert sent successfully to ${contact.name}");
      } catch (e) {
        await EmergencyLogger.log("Error sending SMS to ${contact.name}: $e");
      }
    }).toList();

    await Future.wait(futures);
    return sentCount;
  }
}

/// Service handling background API-based transactional email delivery with offline caching.
class EmergencyEmailService {
  final EmergencyContactRepository _contactsRepo = EmergencyContactRepository();

  EmergencyEmailService() {
    // Set up network connectivity listener to dynamically flush offline queues
    Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (!isOffline) {
        flushQueue();
      }
    });
  }

  Future<void> sendEmergencyEmail(EmergencyPayload payload) async {
    final contacts = await _contactsRepo.getContacts();
    final toEmails = contacts
        .map((c) => c.email.trim())
        .where((email) => email.isNotEmpty)
        .toList();

    if (toEmails.isEmpty) {
      await EmergencyLogger.log("No emergency contact email addresses registered. Email skipped.");
      return;
    }

    final conn = await Connectivity().checkConnectivity();
    final isOffline = conn.contains(ConnectivityResult.none);

    if (isOffline) {
      await queueEmail(toEmails, payload);
      return;
    }

    await _dispatchEmail(toEmails, payload);
  }

  Future<void> queueEmail(List<String> toEmails, EmergencyPayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = prefs.getStringList('queued_emergency_emails') ?? [];

      final queueItem = {
        'to': toEmails,
        'subject': "🚨 RoadSOS EMERGENCY ALERT - ${payload.userName}",
        'payload': payload.toJson(),
      };

      currentQueue.add(json.encode(queueItem));
      await prefs.setStringList('queued_emergency_emails', currentQueue);
      await EmergencyLogger.log("OFFLINE: Email alert successfully queued under 'queued_emergency_emails'.");
    } catch (e) {
      await EmergencyLogger.log("Error queuing offline email: $e");
    }
  }

  Future<void> flushQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = prefs.getStringList('queued_emergency_emails') ?? [];
      if (currentQueue.isEmpty) return;

      await EmergencyLogger.log("Network restored! Flushing ${currentQueue.length} queued emergency emails...");

      final List<Future<void>> futures = currentQueue.map((itemStr) async {
        try {
          final item = json.decode(itemStr) as Map<String, dynamic>;
          final to = List<String>.from(item['to']);
          final subject = item['subject'] as String;
          final payloadJson = item['payload'] as Map<String, dynamic>;
          final payload = EmergencyPayload.fromJson(payloadJson);

          await _dispatchEmailDirect(to, subject, payload, queueOnFailure: false);
        } catch (e) {
          await EmergencyLogger.log("Failed to process queued email flush: $e");
        }
      }).toList();

      await Future.wait(futures);
      await prefs.remove('queued_emergency_emails');
      await EmergencyLogger.log("All queued email queues flushed and cleared.");
    } catch (e) {
      await EmergencyLogger.log("Error flushing queue: $e");
    }
  }

  Future<void> _dispatchEmail(List<String> toEmails, EmergencyPayload payload) async {
    final subject = "🚨 RoadSOS EMERGENCY ALERT - ${payload.userName}";
    await _dispatchEmailDirect(toEmails, subject, payload, queueOnFailure: true);
  }

  Future<void> _dispatchEmailDirect(
    List<String> toEmails,
    String subject,
    EmergencyPayload payload, {
    required bool queueOnFailure,
  }) async {
    final envUrl = dotenv.env['BACKEND_URL'];
    final baseUrl = (envUrl != null && envUrl.isNotEmpty) ? envUrl : "http://localhost:8000";
    final url = Uri.parse("$baseUrl/api/v1/emergency/email");

    try {
      await EmergencyLogger.log("Dispatching transactional email via FastAPI endpoint...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': toEmails,
          'subject': subject,
          'payload': payload.toJson(),
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await EmergencyLogger.log("Email dispatch completed successfully to $toEmails.");
      } else {
        await EmergencyLogger.log("Email dispatch failed with status: ${response.statusCode}.");
        if (queueOnFailure) {
          await queueEmail(toEmails, payload);
        }
      }
    } catch (e) {
      await EmergencyLogger.log("Email dispatch failed with exception: $e.");
      if (queueOnFailure) {
        await queueEmail(toEmails, payload);
      }
    }
  }
}

/// Central Orchestrator coordinating all emergency services in parallel.
class EmergencyCommunicationService {
  final EmergencyCallService callService = EmergencyCallService();
  final EmergencySmsService smsService = EmergencySmsService();
  final EmergencyEmailService emailService = EmergencyEmailService();
  final NearbyServicesRepository hospitalService = NearbyServicesRepository();
  
  final MedicalRepository _medicalRepo = MedicalRepository();
  final EmergencyContactRepository _contactsRepo = EmergencyContactRepository();

  Future<Map<String, dynamic>> triggerEmergency({
    required double lat,
    required double lng,
    required String userName,
    required String emergencyType,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    await EmergencyLogger.log("SOS TRIGGERED (source: $emergencyType)");

    // 1. Resolve human-readable address in the background
    final String address = await performReverseGeocode(lat, lng);
    await EmergencyLogger.log("Address geocoded: $address");

    // 2. Fetch medical profile snapshot
    String? medicalSummary;
    try {
      final profile = await _medicalRepo.getMedicalProfile('me');
      if (profile != null) {
        medicalSummary = "Blood Group: ${profile.bloodGroup}, Allergies: ${profile.allergies.join(', ')}, Conditions: ${profile.conditions.join(', ')}";
      }
    } catch (e) {
      await EmergencyLogger.log("Failed to load Medical ID summary: $e");
    }

    // 3. Fetch contacts snapshot list
    List<String> notifiedContacts = [];
    try {
      final contacts = await _contactsRepo.getContacts();
      notifiedContacts = contacts.map((c) => "${c.name} (${c.phone})").toList();
    } catch (e) {
      await EmergencyLogger.log("Failed to load contact list snapshot: $e");
    }

    final payload = EmergencyPayload(
      userName: userName,
      lat: lat,
      lng: lng,
      address: address,
      timestamp: timestamp,
      emergencyType: emergencyType,
      medicalSummary: medicalSummary,
      notifiedContacts: notifiedContacts,
    );

    bool callTriggered = false;
    int smsCount = 0;
    bool emailSentOrQueued = false;
    dynamic hospitals = [];

    // Step 7 - Execute all concurrently via Future.wait
    await Future.wait([
      callService.call108().then((res) {
        callTriggered = res;
      }).catchError((e) {
        EmergencyLogger.log("Call service error: $e");
      }),
      smsService.sendToAllContacts(lat, lng, userName, timestamp).then((res) {
        smsCount = res;
      }).catchError((e) {
        EmergencyLogger.log("SMS service error: $e");
      }),
      emailService.sendEmergencyEmail(payload).then((_) {
        emailSentOrQueued = true;
      }).catchError((e) {
        EmergencyLogger.log("Email service error: $e");
      }),
      hospitalService.getNearbyHospitals(lat, lng).then((res) {
        hospitals = res;
        if (res.isNotEmpty) {
          final nearest = res.first;
          EmergencyLogger.log("Hospital found: ${nearest.name}, distance: ${nearest.distanceKm} km");
        } else {
          EmergencyLogger.log("No nearby hospital found.");
        }
      }).catchError((e) {
        EmergencyLogger.log("Hospital search error: $e");
      }),
    ]);

    return {
      'callTriggered': callTriggered,
      'smsCount': smsCount,
      'emailSentOrQueued': emailSentOrQueued,
      'hospitals': hospitals,
    };
  }
}
