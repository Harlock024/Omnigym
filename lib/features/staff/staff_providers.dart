import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/app_user.dart';
import '../../core/providers/providers.dart';

// Stream de todos los operadores del tenant activo
final staffListProvider = StreamProvider<List<AppUser>>((ref) async* {
  final tenantId = await ref.watch(activeTenantIdFutureProvider.future);
  if (tenantId == null) {
    yield [];
    return;
  }
  yield* ref.watch(userRepositoryProvider).watchByTenant(tenantId);
});

// Filtro de rol seleccionado (null = todos)
final staffRoleFilterProvider = StateProvider<UserRole?>((ref) => null);

// Filtro de estado seleccionado (null = todos)
final staffStatusFilterProvider = StateProvider<UserStatus?>((ref) => null);

// Lista filtrada derivada
final filteredStaffProvider = Provider<AsyncValue<List<AppUser>>>((ref) {
  return ref.watch(staffListProvider).whenData((staff) {
    final roleFilter = ref.watch(staffRoleFilterProvider);
    final statusFilter = ref.watch(staffStatusFilterProvider);
    return staff.where((u) {
      if (roleFilter != null && u.role != roleFilter) return false;
      if (statusFilter != null && u.status != statusFilter) return false;
      return true;
    }).toList();
  });
});
