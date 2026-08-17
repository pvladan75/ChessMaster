class UserSession {
  final String token;
  final int id;
  final String email;
  final String name;
  final String role; // 'korisnik', 'trener', etc.
  final String accountType; // 'free' or 'premium'

  UserSession({
    required this.token,
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.accountType = 'free',
  });

  bool get isGuest => token.isEmpty;

  /// Rooms override the role for the duration of a session (a trainer can join
  /// someone else's room as a student), so the room route rebuilds the signed-in
  /// session with the role carried in the URL.
  UserSession copyWith({String? role}) {
    return UserSession(
      token: token,
      id: id,
      email: email,
      name: name,
      role: role ?? this.role,
      accountType: accountType,
    );
  }

  factory UserSession.guest() {
    return UserSession(
      token: '',
      id: 0,
      email: 'gost@chesstrainers.app',
      name: 'Gost Korisnik',
      role: 'korisnik',
      accountType: 'free',
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json, String token) {
    return UserSession(
      token: token,
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'korisnik',
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
