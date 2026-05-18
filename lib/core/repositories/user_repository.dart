import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _db;

  const UserRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users');

  Future<void> create(AppUser user) async {
    final json = user.toJson()..remove('id');
    json['created_at'] = FieldValue.serverTimestamp();
    await _col.doc(user.id).set(json);
  }

  Future<AppUser?> get(String uid) async {
    final snap = await _col.doc(uid).get();
    return snap.exists ? AppUser.fromFirestore(snap) : null;
  }

  Stream<AppUser?> watch(String uid) {
    return _col.doc(uid).snapshots().map(
          (snap) => snap.exists ? AppUser.fromFirestore(snap) : null,
        );
  }

  Stream<List<AppUser>> watchByTenant(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  Future<void> updateStatus(String uid, UserStatus status) async {
    await _col.doc(uid).update({'status': status.name});
  }

  Future<void> updateRole(String uid, UserRole role) async {
    await _col.doc(uid).update({'role': role.name});
  }
}
