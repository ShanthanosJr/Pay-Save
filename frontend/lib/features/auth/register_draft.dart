import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the registration steps collect before the account is created.
class RegisterDraft {
  const RegisterDraft({
    this.fullName = '',
    this.age = 0,
    this.nic = '',
    this.phone = '',
    this.phoneVerificationToken = '',
  });

  final String fullName;
  final int age;
  final String nic;
  final String phone;
  final String phoneVerificationToken;

  RegisterDraft copyWith({
    String? fullName,
    int? age,
    String? nic,
    String? phone,
    String? phoneVerificationToken,
  }) =>
      RegisterDraft(
        fullName: fullName ?? this.fullName,
        age: age ?? this.age,
        nic: nic ?? this.nic,
        phone: phone ?? this.phone,
        phoneVerificationToken: phoneVerificationToken ?? this.phoneVerificationToken,
      );
}

class RegisterDraftNotifier extends Notifier<RegisterDraft> {
  @override
  RegisterDraft build() => const RegisterDraft();

  void update(RegisterDraft Function(RegisterDraft d) f) => state = f(state);
  void reset() => state = const RegisterDraft();
}

final registerDraftProvider =
    NotifierProvider<RegisterDraftNotifier, RegisterDraft>(RegisterDraftNotifier.new);
