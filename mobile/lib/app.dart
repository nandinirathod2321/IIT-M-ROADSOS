import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_scope.dart';
import 'core/router/app_router.dart';
import 'presentation/blocs/location/location_cubit.dart';
import 'presentation/blocs/nearby/nearby_cubit.dart';
import 'presentation/blocs/chat/chat_cubit.dart';
import 'core/responders/responder_cubit.dart';

/// Main Application widget for RoadSOS.
/// Outfitted with system scale clamps and light government-style tokens.
///
/// Provides three global cubits at root:
///   • [LocationCubit] — single GPS source for the entire app
///   • [NearbyCubit] — single responder data source (OSM + DB)
///   • [ChatCubit] — first-aid AI assistant chat controller
class RoadSOSApp extends StatelessWidget {
  final String initialLocation;
  final ThemeProvider themeProvider;

  const RoadSOSApp({
    super.key,
    required this.initialLocation,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocationCubit>(
          create: (_) => LocationCubit()..initLocation(),
        ),
        BlocProvider<NearbyCubit>(
          create: (context) => NearbyCubit(
            locationCubit: context.read<LocationCubit>(),
          ),
        ),
        BlocProvider<ResponderCubit>(
          create: (context) => ResponderCubit(
            locationCubit: context.read<LocationCubit>(),
          ),
        ),
        BlocProvider<ChatCubit>(
          create: (_) => ChatCubit(),
        ),
      ],
      child: ThemeScope(
        notifier: themeProvider,
        child: MaterialApp.router(
          title: 'RoadSOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.mode,
          routerConfig: AppRouter.router(initialLocation),
          builder: (context, child) {
            return ListenableBuilder(
              listenable: themeProvider,
              builder: (context, _) {
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
            );
          },
        ),
      ),
    );
  }
}
