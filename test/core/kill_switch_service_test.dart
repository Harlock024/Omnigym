import 'package:flutter_test/flutter_test.dart';
import 'package:omnigym/core/errors/access_errors.dart';
import 'package:omnigym/core/models/branch.dart';
import 'package:omnigym/core/models/member.dart';
import 'package:omnigym/core/models/tenant.dart';
import 'package:omnigym/core/services/kill_switch_service.dart';

void main() {
  const sut = KillSwitchService();
  const branchId = 'branch-01';

  final activeTenant = Tenant(
    id: 't1',
    slug: 'gym-test',
    name: 'Gym Test',
    subscriptionStatus: SubscriptionStatus.active,
    billingCycleEnd: DateTime.now().add(const Duration(days: 30)),
    settings: const TenantSettings(),
  );

  final activeBranch = Branch(
    id: branchId,
    tenantId: 't1',
    name: 'Sucursal Norte',
    isActive: true,
  );

  final activeMember = Member(
    id: 'm1',
    tenantId: 't1',
    name: 'Juan Pérez',
    email: 'juan@test.com',
    accessStatus: AccessStatus.active,
    allowedBranches: [branchId],
    qrToken: 'token-abc',
    expirationDate: DateTime.now().add(const Duration(days: 15)),
  );

  group('KillSwitchService', () {
    test('permite acceso cuando los 3 niveles están OK', () {
      expect(
        () => sut.validate(
          tenant: activeTenant,
          branch: activeBranch,
          member: activeMember,
          targetBranchId: branchId,
        ),
        returnsNormally,
      );
    });

    test('Nivel 0 — lanza TenantSuspendedError si el tenant está suspendido', () {
      final tenant = activeTenant.copyWith(
        subscriptionStatus: SubscriptionStatus.suspended,
      );
      expect(
        () => sut.validate(
          tenant: tenant,
          branch: activeBranch,
          member: activeMember,
          targetBranchId: branchId,
        ),
        throwsA(isA<TenantSuspendedError>()),
      );
    });

    test('Nivel 1 — lanza BranchInactiveError si la sucursal está inactiva', () {
      final branch = activeBranch.copyWith(isActive: false);
      expect(
        () => sut.validate(
          tenant: activeTenant,
          branch: branch,
          member: activeMember,
          targetBranchId: branchId,
        ),
        throwsA(isA<BranchInactiveError>()),
      );
    });

    test('Nivel 2 — lanza MemberSuspendedError si el socio está suspendido', () {
      final member = activeMember.copyWith(
        accessStatus: AccessStatus.suspended,
      );
      expect(
        () => sut.validate(
          tenant: activeTenant,
          branch: activeBranch,
          member: member,
          targetBranchId: branchId,
        ),
        throwsA(isA<MemberSuspendedError>()),
      );
    });

    test('Nivel 2 — lanza MemberExpiredError si la membresía venció', () {
      final member = activeMember.copyWith(
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(
        () => sut.validate(
          tenant: activeTenant,
          branch: activeBranch,
          member: member,
          targetBranchId: branchId,
        ),
        throwsA(isA<MemberExpiredError>()),
      );
    });

    test('Nivel 2 — lanza BranchNotAllowedError si la sucursal no está permitida', () {
      final member = activeMember.copyWith(allowedBranches: ['branch-otra']);
      expect(
        () => sut.validate(
          tenant: activeTenant,
          branch: activeBranch,
          member: member,
          targetBranchId: branchId,
        ),
        throwsA(isA<BranchNotAllowedError>()),
      );
    });

    test('Nivel 0 tiene prioridad sobre Nivel 1 y Nivel 2', () {
      final suspendedTenant = activeTenant.copyWith(
        subscriptionStatus: SubscriptionStatus.cancelled,
      );
      final inactiveBranch = activeBranch.copyWith(isActive: false);
      final expiredMember = activeMember.copyWith(
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(
        () => sut.validate(
          tenant: suspendedTenant,
          branch: inactiveBranch,
          member: expiredMember,
          targetBranchId: branchId,
        ),
        throwsA(isA<TenantSuspendedError>()),
      );
    });
  });
}
