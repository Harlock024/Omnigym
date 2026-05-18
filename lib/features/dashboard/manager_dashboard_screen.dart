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
        return _BranchDetail(tenantId: tenantId, branch: branch);
      },
    );
  }
}

class _BranchDetail extends ConsumerStatefulWidget {
  const _BranchDetail({required this.tenantId, required this.branch});
  final String tenantId;
  final Branch branch;

  @override
  ConsumerState<_BranchDetail> createState() => _BranchDetailState();
}

class _BranchDetailState extends ConsumerState<_BranchDetail> {
  DateTimeRange? _dateRange;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 6)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final args = (tenantId: widget.tenantId, branchId: widget.branch.id);

    final membersAsync = ref.watch(activeMemberCountProvider(args));
    final checkInsAsync = ref.watch(todayCheckInCountProvider(args));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─ Encabezado sucursal ─
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.branch.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      widget.branch.isActive
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: widget.branch.isActive ? cs.primary : cs.error,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(widget.branch.isActive
                        ? 'Sucursal activa'
                        : 'Sucursal inactiva'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─ Métricas del día ─
        _StatCard(
          label: 'Socios activos',
          icon: Icons.people,
          valueAsync: membersAsync,
        ),
        const SizedBox(height: 8),
        _StatCard(
          label: 'Check-ins hoy',
          icon: Icons.login,
          valueAsync: checkInsAsync,
        ),
        const SizedBox(height: 20),

        // ─ Selector de rango histórico ─
        Row(
          children: [
            Text('Reporte histórico',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                _dateRange == null
                    ? 'Seleccionar fechas'
                    : '${_fmt(_dateRange!.start)} – ${_fmt(_dateRange!.end)}',
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: _pickDateRange,
            ),
          ],
        ),
        if (_dateRange != null) ...[
          const SizedBox(height: 8),
          _HistoricalCheckInsCard(
            tenantId: widget.tenantId,
            branchId: widget.branch.id,
            range: _dateRange!,
          ),
        ],
      ],
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ─── Stat card con datos reales ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.valueAsync,
  });

  final String label;
  final IconData icon;
  final AsyncValue<int> valueAsync;

  @override
  Widget build(BuildContext context) {
    final value = valueAsync.when(
      loading: () => '…',
      error: (e, s) => '?',
      data: (v) => v.toString(),
    );

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

// ─── Reporte histórico de check-ins ──────────────────────────────────────────

class _HistoricalCheckInsCard extends ConsumerWidget {
  const _HistoricalCheckInsCard({
    required this.tenantId,
    required this.branchId,
    required this.range,
  });

  final String tenantId;
  final String branchId;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      StreamProvider((r) => r
          .watch(branchRepositoryProvider)
          .watchRangeCheckInCount(tenantId, branchId, range.start, range.end)),
    );

    return Card(
      child: ListTile(
        leading:
            Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
        title: const Text('Check-ins en el rango'),
        trailing: countAsync.when(
          loading: () => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (e, s) => const Text('?'),
          data: (v) => Text(
            v.toString(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
