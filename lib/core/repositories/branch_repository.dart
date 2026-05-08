import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch.dart';

class BranchRepository {
  final FirebaseFirestore _db;

  const BranchRepository(this._db);

  CollectionReference<Map<String, dynamic>> _col(String tenantId) =>
      _db.collection('tenants').doc(tenantId).collection('branches');

  Stream<List<Branch>> watchAll(String tenantId) {
    return _col(tenantId).orderBy('name').snapshots().map(
          (snap) => snap.docs.map(Branch.fromFirestore).toList(),
        );
  }

  Stream<Branch?> watch(String tenantId, String branchId) {
    return _col(tenantId).doc(branchId).snapshots().map(
          (snap) => snap.exists ? Branch.fromFirestore(snap) : null,
        );
  }

  Future<Branch?> get(String tenantId, String branchId) async {
    final snap = await _col(tenantId).doc(branchId).get();
    return snap.exists ? Branch.fromFirestore(snap) : null;
  }

  Future<String> create(Branch branch) async {
    final json = branch.toJson()..remove('id');
    json['created_at'] = FieldValue.serverTimestamp();
    final ref = await _col(branch.tenantId).add(json);
    return ref.id;
  }

  Future<void> setActive(
    String tenantId,
    String branchId, {
    required bool isActive,
  }) async {
    await _col(tenantId).doc(branchId).update({'is_active': isActive});
  }

  Future<void> update(Branch branch) async {
    final json = branch.toJson()..remove('id')..remove('tenant_id');
    await _col(branch.tenantId).doc(branch.id).update(json);
  }
}
