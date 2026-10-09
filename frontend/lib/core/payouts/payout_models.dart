/// How a member wants to receive money. Full details only ever reach their
/// owner, or the one member who has to pay them this cycle.
enum PayoutKind {
  bankTransfer('bank_transfer'),
  mobileWallet('mobile_wallet'),
  lankaqr('lankaqr'),
  cash('cash');

  const PayoutKind(this.wire);
  final String wire;

  static PayoutKind parse(Object? v) => values.firstWhere((k) => k.wire == v, orElse: () => cash);
}

/// Decrypted details; which fields are set depends on [kind].
class PayoutDetails {
  const PayoutDetails({
    required this.kind,
    this.bankName,
    this.branch,
    this.accountName,
    this.accountNumber,
    this.provider,
    this.number,
    this.merchantName,
    this.reference,
    this.note,
  });

  final PayoutKind kind;
  final String? bankName;
  final String? branch;
  final String? accountName;
  final String? accountNumber;
  final String? provider;
  final String? number;
  final String? merchantName;
  final String? reference;
  final String? note;

  factory PayoutDetails.fromJson(Map<String, dynamic> j) => PayoutDetails(
    kind: PayoutKind.parse(j['kind']),
    bankName: j['bankName'] as String?,
    branch: j['branch'] as String?,
    accountName: j['accountName'] as String?,
    accountNumber: j['accountNumber'] as String?,
    provider: j['provider'] as String?,
    number: j['number'] as String?,
    merchantName: j['merchantName'] as String?,
    reference: j['reference'] as String?,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'bankName': ?bankName,
    'branch': ?branch,
    'accountName': ?accountName,
    'accountNumber': ?accountNumber,
    'provider': ?provider,
    'number': ?number,
    'merchantName': ?merchantName,
    'reference': ?reference,
    'note': ?note,
  };
}

class PayoutMethod {
  const PayoutMethod({
    required this.id,
    required this.kind,
    required this.summary,
    required this.details,
    this.isDefault = false,
    this.preferred = false,
  });

  final String id;
  final PayoutKind kind;

  /// Already masked by the server, e.g. "Bank of Ceylon · ••••6789".
  final String summary;
  final PayoutDetails details;
  final bool isDefault;

  /// For a method shared with a circle: the one payers should use first.
  final bool preferred;

  factory PayoutMethod.fromJson(Map<String, dynamic> j) => PayoutMethod(
    id: j['id'] as String,
    kind: PayoutKind.parse(j['kind']),
    summary: j['summary'] as String,
    details: PayoutDetails.fromJson(j['details'] as Map<String, dynamic>),
    isDefault: j['isDefault'] as bool? ?? false,
    preferred: j['preferred'] as bool? ?? false,
  );
}

/// A shared method as circle setup shows it: masked, no details.
class PayoutSummary {
  const PayoutSummary({required this.id, required this.kind, required this.summary, this.preferred = false});

  final String id;
  final PayoutKind kind;
  final String summary;
  final bool preferred;

  factory PayoutSummary.fromJson(Map<String, dynamic> j) => PayoutSummary(
    id: j['id'] as String,
    kind: PayoutKind.parse(j['kind']),
    summary: j['summary'] as String,
    preferred: j['preferred'] as bool? ?? false,
  );
}
