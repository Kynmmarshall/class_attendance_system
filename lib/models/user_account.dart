class UserAccount {
  final String fullName;
  final String email;
  final String password;
  final DateTime registeredAt;

  const UserAccount({
    required this.fullName,
    required this.email,
    required this.password,
    required this.registeredAt,
  });

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'password': password,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }
}
