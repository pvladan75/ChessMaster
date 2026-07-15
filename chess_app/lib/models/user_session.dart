class UserSession {
  final String token;
  final int id;
  final String email;
  final String name;
  final String role; // 'trener' or 'ucenik'

  UserSession({
    required this.token,
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserSession.fromJson(Map<String, dynamic> json, String token) {
    return UserSession(
      token: token,
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
    );
  }
}
