/// Vending operator identity returned by `GET /api/v1/operators/me`.
///
/// Mirrors NexoVending `OperatorOut`. Does not authorize business operations.
final class Operator {
  Operator({
    required this.operatorId,
    required this.tenantId,
    required this.role,
    required this.status,
    required this.provider,
    required this.subject,
    this.displayName,
    this.email,
  }) {
    if (operatorId.trim().isEmpty) {
      throw ArgumentError.value(operatorId, 'operatorId', 'must not be empty');
    }
    if (tenantId.trim().isEmpty) {
      throw ArgumentError.value(tenantId, 'tenantId', 'must not be empty');
    }
    if (role.trim().isEmpty) {
      throw ArgumentError.value(role, 'role', 'must not be empty');
    }
    if (status.trim().isEmpty) {
      throw ArgumentError.value(status, 'status', 'must not be empty');
    }
    if (provider.trim().isEmpty) {
      throw ArgumentError.value(provider, 'provider', 'must not be empty');
    }
    if (subject.trim().isEmpty) {
      throw ArgumentError.value(subject, 'subject', 'must not be empty');
    }
  }

  final String operatorId;
  final String tenantId;
  final String role;
  final String status;
  final String? displayName;
  final String? email;
  final String provider;
  final String subject;

  /// Preferred label for UI (never a token).
  String get welcomeName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail;
    }
    return operatorId;
  }

  factory Operator.fromJson(Map<String, Object?> json) {
    final operatorId = json['operator_id'] as String?;
    final tenantId = json['tenant_id'] as String?;
    final role = json['role'] as String?;
    final status = json['status'] as String?;
    final provider = json['provider'] as String?;
    final subject = json['subject'] as String?;

    if (operatorId == null ||
        tenantId == null ||
        role == null ||
        status == null ||
        provider == null ||
        subject == null) {
      throw const FormatException('Operator JSON missing required fields');
    }

    return Operator(
      operatorId: operatorId,
      tenantId: tenantId,
      role: role,
      status: status,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      provider: provider,
      subject: subject,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'operator_id': operatorId,
      'tenant_id': tenantId,
      'role': role,
      'status': status,
      'display_name': displayName,
      'email': email,
      'provider': provider,
      'subject': subject,
    };
  }

  @override
  String toString() {
    return 'Operator(operatorId: $operatorId, tenantId: $tenantId, '
        'role: $role, status: $status, displayName: $displayName)';
  }
}
