import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'tenant.freezed.dart';
part 'tenant.g.dart';

enum SubscriptionStatus { active, suspended, cancelled }

@freezed
class Tenant with _$Tenant {
  const factory Tenant({
    required String id,
    required String slug,
    required String name,
    @JsonKey(name: 'subscription_status')
    required SubscriptionStatus subscriptionStatus,
    @JsonKey(name: 'billing_cycle_end')
    @TimestampConverter()
    required DateTime billingCycleEnd,
    required TenantSettings settings,
    @JsonKey(name: 'created_at')
    @NullableTimestampConverter()
    DateTime? createdAt,
  }) = _Tenant;

  factory Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);

  static Tenant fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Tenant.fromJson({...doc.data()!, 'id': doc.id});
  }
}

@freezed
class TenantSettings with _$TenantSettings {
  const factory TenantSettings({
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'primary_color') @Default('#1976D2') String primaryColor,
    @JsonKey(name: 'accent_color') @Default('#FF6F00') String accentColor,
    String? rfc,
    @JsonKey(name: 'razon_social') String? razonSocial,
    @JsonKey(name: 'regimen_fiscal_key') String? regimenFiscalKey,
  }) = _TenantSettings;

  factory TenantSettings.fromJson(Map<String, dynamic> json) =>
      _$TenantSettingsFromJson(json);
}
