import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tenant.dart';
import '../models/app_user.dart';
import '../repositories/branch_repository.dart';
import '../repositories/member_repository.dart';
import '../repositories/tenant_repository.dart';
import '../repositories/user_repository.dart';
import '../services/kill_switch_service.dart';

// ─── Firebase instances ───────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (_) => FirebaseStorage.instance,
);

// ─── Auth ────────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

// ─── Repositories ─────────────────────────────────────────────────────────────

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => TenantRepository(ref.watch(firestoreProvider)),
);

final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => BranchRepository(ref.watch(firestoreProvider)),
);

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(ref.watch(firestoreProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

// ─── Services ────────────────────────────────────────────────────────────────

final killSwitchServiceProvider = Provider<KillSwitchService>(
  (_) => const KillSwitchService(),
);

// ─── Tenant activo (leído de custom claims del JWT) ──────────────────────────

final activeTenantIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  // El tenant_id viene en los custom claims del JWT
  // Se obtiene de forma asíncrona vía getIdTokenResult()
  return null; // ver activeTenantIdFutureProvider
});

final activeTenantIdFutureProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final result = await user.getIdTokenResult();
  return result.claims?['tenant_id'] as String?;
});

final activeTenantProvider = StreamProvider<Tenant?>((ref) async* {
  final tenantId = await ref.watch(activeTenantIdFutureProvider.future);
  if (tenantId == null) {
    yield null;
    return;
  }
  yield* ref.watch(tenantRepositoryProvider).watch(tenantId);
});

// ─── Rol del usuario actual ───────────────────────────────────────────────────

final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final result = await user.getIdTokenResult();
  return result.claims?['role'] as String?;
});

final currentBranchIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final result = await user.getIdTokenResult();
  return result.claims?['branch_id'] as String?;
});

// ─── Perfil del usuario autenticado (desde Firestore /users/{uid}) ────────────

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(user.uid);
});
