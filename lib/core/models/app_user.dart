import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

enum UserRole { superuser, owner, staff }

enum UserStatus { active, suspended }

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    @JsonKey(name: 'tenant_id') String? tenantId,
    @JsonKey(name: 'branch_id') String? branchId,
    required String name,
    required String email,
    required UserRole role,
    required UserStatus status,
    @JsonKey(name: 'created_at')
    @NullableTimestampConverter()
    DateTime? createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  static AppUser fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser.fromJson({...doc.data()!, 'id': doc.id});
  }
}
