import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/location/location_cubit.dart';
import 'core/responders/responder_cubit.dart';

/// Main Application widget for RoadSOS.
/// Outfitted with system scale clamps and dark styling tokens.
///
/// Provides two global cubits at root:
///   • [LocationCubit] — single GPS source for the entire app
///   • [ResponderCubit] — single responder data source (hospitals/police/towing/shelters)
class RoadSOSApp extends StatelessWidget {
  final String initialLocation;
  const RoadSOSApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocationCubit>(
      create: (_) => LocationCubit()..initLocation(),
      child: Builder(
        builder: (locationCtx) {
          return BlocProvider<ResponderCubit>(
            create: (_) => ResponderCubit(
              locationCubit: locationCtx.read<LocationCubit>(),
            ),
            child: MaterialApp.router(
              title: 'RoadSOS',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark,
              routerConfig: AppRouter.router(initialLocation),

              builder: (context, child) {
                // Clamp text scale — prevents system large fonts breaking emergency UI
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.2),
                    ),
                  ),
                  child: child!,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
