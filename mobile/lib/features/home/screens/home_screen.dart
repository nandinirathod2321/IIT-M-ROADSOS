import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Crash detection indicator bar
                CrashDetectionBar(isActive: state.crashDetectionEnabled),

                // Status bar
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

                        // SOS button
                        Center(
                          child: HomeSosButton(
                            crashDetectorActive: state.crashDetectionEnabled,
                            onTriggered: () => context.go('/countdown'),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Quick services
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

                        // Nearest hospital
                        NearestHospitalCard(
                          hospital: state.nearestHospital,
                          isLoading: state.isLoading,
                        ),

                        const SizedBox(height: 20),

                        // Protection status
                        ProtectionStatusCard(
                          crashDetectionEnabled: state.crashDetectionEnabled,
                          meshStatus: state.meshStatus,
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
