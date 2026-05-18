import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/tenant.dart';
import '../../core/providers/providers.dart';

// Paleta de colores de marca predefinidos para el color picker
const _brandColors = [
  Color(0xFF1976D2), // Azul Material
  Color(0xFF388E3C), // Verde
  Color(0xFFD32F2F), // Rojo
  Color(0xFFF57C00), // Naranja
  Color(0xFF7B1FA2), // Morado
  Color(0xFF0097A7), // Cyan
  Color(0xFF455A64), // Azul gris
  Color(0xFF212121), // Negro
  Color(0xFFE91E63), // Rosa
  Color(0xFF00796B), // Teal
  Color(0xFFAFB42B), // Lima
  Color(0xFF5D4037), // Café
];

class TenantBrandingScreen extends ConsumerStatefulWidget {
  const TenantBrandingScreen({super.key});

  @override
  ConsumerState<TenantBrandingScreen> createState() =>
      _TenantBrandingScreenState();
}

class _TenantBrandingScreenState extends ConsumerState<TenantBrandingScreen> {
  bool _uploadingLogo = false;
  bool _saving = false;
  Color? _selectedPrimary;
  Color? _selectedAccent;

  Future<void> _pickAndUploadLogo(String tenantId, TenantSettings current) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El logo no puede superar 2 MB.')),
        );
      }
      return;
    }

    setState(() => _uploadingLogo = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref('tenant_logos/$tenantId/logo.png');
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/png'),
      );
      final url = await storageRef.getDownloadURL();
      await ref
          .read(tenantRepositoryProvider)
          .updateSettings(tenantId, current.copyWith(logoUrl: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo actualizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _saveColors(
    String tenantId,
    TenantSettings current,
  ) async {
    if (_selectedPrimary == null && _selectedAccent == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(tenantRepositoryProvider).updateSettings(
            tenantId,
            current.copyWith(
              primaryColor: _selectedPrimary != null
                  ? '#${(_selectedPrimary!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                  : current.primaryColor,
              accentColor: _selectedAccent != null
                  ? '#${(_selectedAccent!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                  : current.accentColor,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colores aplicados a todos los dispositivos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(activeTenantProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia del gimnasio')),
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenant) {
          if (tenant == null) {
            return const Center(child: Text('Tenant no encontrado.'));
          }
          return _BrandingBody(
            tenant: tenant,
            uploadingLogo: _uploadingLogo,
            saving: _saving,
            selectedPrimary: _selectedPrimary,
            selectedAccent: _selectedAccent,
            onPickLogo: () => _pickAndUploadLogo(tenant.id, tenant.settings),
            onSelectPrimary: (c) => setState(() => _selectedPrimary = c),
            onSelectAccent: (c) => setState(() => _selectedAccent = c),
            onSaveColors: () => _saveColors(tenant.id, tenant.settings),
          );
        },
      ),
    );
  }
}

class _BrandingBody extends StatelessWidget {
  const _BrandingBody({
    required this.tenant,
    required this.uploadingLogo,
    required this.saving,
    required this.selectedPrimary,
    required this.selectedAccent,
    required this.onPickLogo,
    required this.onSelectPrimary,
    required this.onSelectAccent,
    required this.onSaveColors,
  });

  final dynamic tenant; // Tenant
  final bool uploadingLogo;
  final bool saving;
  final Color? selectedPrimary;
  final Color? selectedAccent;
  final VoidCallback onPickLogo;
  final ValueChanged<Color> onSelectPrimary;
  final ValueChanged<Color> onSelectAccent;
  final VoidCallback onSaveColors;

  @override
  Widget build(BuildContext context) {
    final settings = (tenant as dynamic).settings as TenantSettings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LogoSection(
              logoUrl: settings.logoUrl,
              uploading: uploadingLogo,
              onTap: onPickLogo,
            ),
            const SizedBox(height: 32),
            Text(
              'Color primario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ColorGrid(
              current: settings.primaryColor,
              selected: selectedPrimary,
              onSelect: onSelectPrimary,
            ),
            const SizedBox(height: 24),
            Text(
              'Color de acento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ColorGrid(
              current: settings.accentColor,
              selected: selectedAccent,
              onSelect: onSelectAccent,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: saving ? null : onSaveColors,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aplicar colores'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.logoUrl,
    required this.uploading,
    required this.onTap,
  });

  final String? logoUrl;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logo del gimnasio',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: uploading ? null : onTap,
          child: Container(
            height: 120,
            width: 200,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline),
              image: logoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(logoUrl!),
                      fit: BoxFit.contain,
                    )
                  : null,
            ),
            child: uploading
                ? const Center(child: CircularProgressIndicator())
                : logoUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: cs.onSurfaceVariant),
                          const SizedBox(height: 6),
                          Text('Subir logo',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.primary,
                            child: Icon(Icons.edit,
                                size: 16, color: cs.onPrimary),
                          ),
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PNG o JPG · máx. 2 MB · recomendado 512×512 px',
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
      ],
    );
  }
}

// ─── Color grid ───────────────────────────────────────────────────────────────

class _ColorGrid extends StatelessWidget {
  const _ColorGrid({
    required this.current,
    required this.selected,
    required this.onSelect,
  });

  final String current;
  final Color? selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _brandColors.map((color) {
        final hexVal =
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        final isActive =
            selected == color || (selected == null && hexVal == current);
        return GestureDetector(
          onTap: () => onSelect(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8)]
                  : null,
            ),
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
