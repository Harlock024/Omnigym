import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/branch.dart';
import '../../core/providers/providers.dart';

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantIdAsync = ref.watch(activeTenantIdFutureProvider);
    final branchIdAsync = ref.watch(currentBranchIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Sucursal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mi perfil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
          ),
        ],
      ),
      body: tenantIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenantId) => branchIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (branchId) {
            if (tenantId == null || branchId == null) {
              return const Center(child: Text('Sin sucursal asignada.'));
            }
            return _ManagerBranchBody(
              tenantId: tenantId,
              branchId: branchId,
            );
          },
        ),
      ),
    );
  }
}

class _ManagerBranchBody extends ConsumerWidget {
  const _ManagerBranchBody({
    required this.tenantId,
    required this.branchId,
  });

  final String tenantId;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(
      StreamProvider(
        (r) => r.watch(branchRepositoryProvider).watch(tenantId, branchId),
      ),
    );

    return branchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (branch) {
        if (branch == null) {
          return const Center(child: Text('Sucursal no encontrada.'));
        }
        return _BranchDetail(branch: branch);
      },
    );
  }
}

class _BranchDetail extends StatelessWidget {
  const _BranchDetail({required this.branch});
  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      branch.isActive ? Icons.check_circle : Icons.cancel,
                      color: branch.isActive ? cs.primary : cs.error,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(branch.isActive ? 'Sucursal activa' : 'Sucursal inactiva'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // TODO Feature #5: socios activos, check-ins del día, rango de fechas
        _StatCard(label: 'Socios activos', value: '—', icon: Icons.people),
        const SizedBox(height: 8),
        _StatCard(
          label: 'Check-ins hoy',
          value: '—',
          icon: Icons.login,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
