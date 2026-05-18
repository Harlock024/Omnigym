import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/providers.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/owner_dashboard_screen.dart';
import '../features/dashboard/manager_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final user = authAsync.valueOrNull;

      if (user == null) {
        return state.matchedLocation == '/login' ? null : '/login';
      }

      if (state.matchedLocation == '/login') {
        final role = await ref.read(currentUserRoleProvider.future);
        return _homeForRole(role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard/owner',
        builder: (context, _) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/manager',
        builder: (context, _) => const ManagerDashboardScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
    ),
  );
});

String _homeForRole(String? role) {
  switch (role) {
    case 'superuser':
    case 'owner':
      return '/dashboard/owner';
    case 'staff':
      return '/dashboard/manager';
    default:
      return '/login';
  }
}
