class SavedAccount {
  final String uid;
  final String email;
  final String displayName;
  final String profilePicUrl;

  SavedAccount({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.profilePicUrl = '',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'profilePicUrl': profilePicUrl,
      };

  factory SavedAccount.fromMap(Map<String, dynamic> map) => SavedAccount(
        uid: map['uid'] ?? '',
        email: map['email'] ?? '',
        displayName: map['displayName'] ?? '',
        profilePicUrl: map['profilePicUrl'] ?? '',
      );
}
