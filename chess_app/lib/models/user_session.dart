class UserSession {
  final String token;
  final int id;
  final String email;
  final String name;
  final String role; // 'trener' or 'ucenik'
  final String accountType; // 'free' or 'premium'

  UserSession({
    required this.token,
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.accountType = 'free',
  });

  factory UserSession.fromJson(Map<String, dynamic> json, String token) {
    return UserSession(
      token: token,
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
      accountType: json['account_type'] ?? 'free',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'account_type': accountType,
    };
  }
}
