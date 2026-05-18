import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/app_user.dart';
import '../../core/providers/providers.dart';
import 'change_password_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _initControllers(AppUser user) {
    _nameCtrl = TextEditingController(text: user.name);
    _phoneCtrl = TextEditingController(text: user.phone ?? '');
  }

  Future<void> _pickAndUploadPhoto(AppUser user) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen no puede superar 2 MB.')),
        );
      }
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('profile_photos/${user.id}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await this.ref
          .read(userRepositoryProvider)
          .updateProfile(user.id, name: user.name, photoUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile(AppUser user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
            user.id,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Usuario no encontrado.'));
          }
          // Inicializa los controllers solo la primera vez
          if (!_formKey.currentState.runtimeType.toString().contains('Form')) {
            _initControllersOnce(user);
          }
          return _ProfileBody(
            user: user,
            formKey: _formKey,
            nameCtrl: _nameCtrl,
            phoneCtrl: _phoneCtrl,
            saving: _saving,
            uploadingPhoto: _uploadingPhoto,
            onSave: () => _saveProfile(user),
            onPickPhoto: () => _pickAndUploadPhoto(user),
            onChangePassword: () => showDialog(
              context: context,
              builder: (_) => const ChangePasswordDialog(),
            ),
          );
        },
      ),
    );
  }

  bool _controllersInitialized = false;
  void _initControllersOnce(AppUser user) {
    if (_controllersInitialized) return;
    _controllersInitialized = true;
    _initControllers(user);
  }
}

// ─── Cuerpo ───────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.user,
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.saving,
    required this.uploadingPhoto,
    required this.onSave,
    required this.onPickPhoto,
    required this.onChangePassword,
  });

  final AppUser user;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool saving;
  final bool uploadingPhoto;
  final VoidCallback onSave;
  final VoidCallback onPickPhoto;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AvatarSection(
              user: user,
              uploading: uploadingPhoto,
              onTap: onPickPhoto,
            ),
            const SizedBox(height: 32),
            _EditForm(
              formKey: formKey,
              nameCtrl: nameCtrl,
              phoneCtrl: phoneCtrl,
              saving: saving,
              onSave: onSave,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onChangePassword,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Cambiar contraseña'),
            ),
            const SizedBox(height: 32),
            _NotificationPrefsSection(user: user),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.user,
    required this.uploading,
    required this.onTap,
  });

  final AppUser user;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: cs.primaryContainer,
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 36, color: cs.onPrimaryContainer),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: uploading ? null : onTap,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary,
                child: uploading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : Icon(Icons.camera_alt, size: 18, color: cs.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formulario de datos ──────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

// ─── Preferencias de notificación ────────────────────────────────────────────

class _NotificationPrefsSection extends ConsumerWidget {
  const _NotificationPrefsSection({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = user.notificationPrefs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notificaciones',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _PrefTile(
          label: 'Check-ins en mi sucursal',
          value: prefs.checkIns,
          onChanged: (v) => _update(ref, prefs.copyWith(checkIns: v)),
        ),
        _PrefTile(
          label: 'Pagos y cobros',
          value: prefs.payments,
          onChanged: (v) => _update(ref, prefs.copyWith(payments: v)),
        ),
        _PrefTile(
          label: 'Membresías próximas a vencer',
          value: prefs.memberExpiry,
          onChanged: (v) => _update(ref, prefs.copyWith(memberExpiry: v)),
        ),
        _PrefTile(
          label: 'Noticias y promociones',
          value: prefs.marketing,
          onChanged: (v) => _update(ref, prefs.copyWith(marketing: v)),
        ),
      ],
    );
  }

  void _update(WidgetRef ref, NotificationPrefs updated) {
    ref.read(userRepositoryProvider).updateNotificationPrefs(user.id, updated);
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
