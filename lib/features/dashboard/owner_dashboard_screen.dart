import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/branch.dart';
import '../../core/providers/providers.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(activeTenantProvider);

    return Scaffold(
      appBar: AppBar(
        title: tenantAsync.whenOrNull(
              data: (t) => Text(t?.name ?? 'OmniGym'),
            ) ??
            const Text('OmniGym'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Equipo',
            onPressed: () => context.push('/staff'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
          ),
        ],
      ),
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenant) {
          if (tenant == null) {
            return const Center(child: Text('Tenant no encontrado.'));
          }
          return _OwnerDashboardBody(tenantId: tenant.id);
        },
      ),
    );
  }
}

class _OwnerDashboardBody extends ConsumerWidget {
  const _OwnerDashboardBody({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(
      StreamProvider((r) => r.watch(branchRepositoryProvider).watchAll(tenantId)),
    );

    return branchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (branches) => _BranchGrid(branches: branches),
    );
  }
}

class _BranchGrid extends StatelessWidget {
  const _BranchGrid({required this.branches});
  final List<Branch> branches;

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const Center(child: Text('No hay sucursales registradas.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: branches.length,
      itemBuilder: (_, i) => _BranchCard(branch: branches[i]),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch});
  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branch.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? cs.primaryContainer
                        : cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    branch.isActive ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      fontSize: 11,
                      color: branch.isActive
                          ? cs.onPrimaryContainer
                          : cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // TODO Feature #5: aquí irán métricas reales (socios activos, check-ins del día)
            Text(
              'Socios activos: —',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Check-ins hoy: —',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
