class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.age,
    required this.email,
    required this.emailVerified,
    required this.phoneMasked,
    required this.phoneVerified,
    required this.nicMasked,
    required this.language,
  });

  final String id;
  final String fullName;
  final int age;
  final String? email;
  final bool emailVerified;
  final String phoneMasked;
  final bool phoneVerified;
  final String nicMasked;
  final String language;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({bool? emailVerified, String? language}) => UserProfile(
        id: id,
        fullName: fullName,
        age: age,
        email: email,
        emailVerified: emailVerified ?? this.emailVerified,
        phoneMasked: phoneMasked,
        phoneVerified: phoneVerified,
        nicMasked: nicMasked,
        language: language ?? this.language,
      );

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        age: (j['age'] as num).toInt(),
        email: j['email'] as String?,
        emailVerified: j['emailVerified'] as bool? ?? false,
        phoneMasked: j['phoneMasked'] as String? ?? '',
        phoneVerified: j['phoneVerified'] as bool? ?? false,
        nicMasked: j['nicMasked'] as String? ?? '',
        language: j['language'] as String? ?? 'en',
      );
}

class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final UserProfile user;
  final AuthTokens tokens;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        user: UserProfile.fromJson(j['user'] as Map<String, dynamic>),
        tokens: AuthTokens.fromJson(j),
      );
}

class OtpChallenge {
  const OtpChallenge({required this.resendAfterSeconds, this.devCode});

  final int resendAfterSeconds;
  final String? devCode;

  factory OtpChallenge.fromJson(Map<String, dynamic> j) => OtpChallenge(
        resendAfterSeconds: (j['resendAfterSeconds'] as num?)?.toInt() ?? 30,
        devCode: j['devCode'] as String?,
      );
}
