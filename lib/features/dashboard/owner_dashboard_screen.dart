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
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Apariencia',
            onPressed: () => context.push('/settings/branding'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Equipo',
            onPressed: () => context.push('/staff'),
          ),
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
      data: (branches) => _BranchGrid(tenantId: tenantId, branches: branches),
    );
  }
}

class _BranchGrid extends StatelessWidget {
  const _BranchGrid({required this.tenantId, required this.branches});
  final String tenantId;
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
        childAspectRatio: 1.3,
      ),
      itemCount: branches.length,
      itemBuilder: (_, i) =>
          _BranchCard(tenantId: tenantId, branch: branches[i]),
    );
  }
}

class _BranchCard extends ConsumerWidget {
  const _BranchCard({required this.tenantId, required this.branch});
  final String tenantId;
  final Branch branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final args = (tenantId: tenantId, branchId: branch.id);

    final membersAsync = ref.watch(activeMemberCountProvider(args));
    final checkInsAsync = ref.watch(todayCheckInCountProvider(args));

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            _MetricRow(
              icon: Icons.people_outline,
              label: 'Socios activos',
              valueAsync: membersAsync,
            ),
            const SizedBox(height: 4),
            _MetricRow(
              icon: Icons.login,
              label: 'Check-ins hoy',
              valueAsync: checkInsAsync,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.valueAsync,
  });

  final IconData icon;
  final String label;
  final AsyncValue<int> valueAsync;

  @override
  Widget build(BuildContext context) {
    final value = valueAsync.whenOrNull(data: (v) => v.toString()) ?? '…';
    return Row(
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
