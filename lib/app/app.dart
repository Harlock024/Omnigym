import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/providers.dart';
import '../core/services/theme_service.dart';
import 'router.dart';

class OmniGymApp extends ConsumerWidget {
  const OmniGymApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final tenantAsync = ref.watch(activeTenantProvider);

    // El tema se adapta dinámicamente al tenant activo (white-labeling)
    final theme = tenantAsync.whenOrNull(
          data: (tenant) => tenant != null
              ? ThemeService.fromSettings(tenant.settings)
              : null,
        ) ??
        ThemeService.defaultTheme;

    return MaterialApp.router(
      title: 'OmniGym',
      theme: theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
