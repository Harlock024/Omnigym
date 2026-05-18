import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/models/tenant.dart';
import '../../core/providers/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _gymNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gymNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final auth = ref.read(firebaseAuthProvider);
      final db = ref.read(firestoreProvider);

      // 1. Crear cuenta en Firebase Auth
      final credential = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(_nameCtrl.text.trim());

      // 2. Crear el Tenant
      final gymName = _gymNameCtrl.text.trim();
      final tenantRef = db.collection('tenants').doc();
      final tenantId = tenantRef.id;
      await tenantRef.set({
        'name': gymName,
        'slug': _slugify(gymName),
        'subscription_status': SubscriptionStatus.active.name,
        'billing_cycle_end': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
        'settings': const TenantSettings().toJson(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // 3. Crear documento en /users/{uid} — dispara onUserWritten
      await db.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': UserRole.owner.name,
        'status': UserStatus.active.name,
        'tenant_id': tenantId,
        'branch_id': null,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 4. Esperar que onUserWritten asigne los claims (máx ~5s)
      // Sin esto el router lee role=null y regresa a /login
      await _waitForClaims(credential.user!);

      // El router reacciona al cambio de authState y redirige a /dashboard/owner
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapError(e.code));
    } catch (e) {
      setState(() => _error = 'Error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Fuerza refresh del JWT hasta que el claim 'role' aparezca.
  // onUserWritten es un trigger de Firestore — tarda ~1-3s en producción.
  Future<void> _waitForClaims(User user) async {
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      final result = await user.getIdTokenResult(true);
      if (result.claims?['role'] != null) return;
    }
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'ñ'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _mapError(String code) => switch (code) {
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'invalid-email' => 'Correo electrónico inválido.',
        'weak-password' => 'La contraseña es muy débil (mínimo 6 caracteres).',
        _ => 'Error al crear la cuenta. Intenta de nuevo.',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registra tu gimnasio',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu cuenta de Owner y empieza a gestionar tu cadena.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Nombre del gym
                  TextFormField(
                    controller: _gymNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del gimnasio',
                      prefixIcon: Icon(Icons.fitness_center),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Nombre del owner
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (!v.contains('@')) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contraseña
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirmar contraseña
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) =>
                        v != _passCtrl.text
                            ? 'Las contraseñas no coinciden'
                            : null,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: cs.error, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 28),

                  if (_loading)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'Configurando tu cuenta…',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    )
                  else
                    FilledButton(
                      onPressed: _register,
                      child: const Text('Crear cuenta'),
                    ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
