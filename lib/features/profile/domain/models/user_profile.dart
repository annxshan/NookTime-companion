/// Model representing user personal details and preferences used for AI routine customization.
class UserProfile {
  final String name;
  final int? age;
  final String designation; // e.g. 'Student', 'Employee', 'Worker', 'Freelancer', 'Other'
  final List<String> hobbies;
  final String? avatarPath; // Local image path or avatar preset

  const UserProfile({
    this.name = '',
    this.age,
    this.designation = 'Student',
    this.hobbies = const [],
    this.avatarPath,
  });

  UserProfile copyWith({
    String? name,
    int? age,
    bool clearAge = false,
    String? designation,
    List<String>? hobbies,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: clearAge ? null : (age ?? this.age),
      designation: designation ?? this.designation,
      hobbies: hobbies ?? this.hobbies,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  /// Formats non-empty user details into a string suitable for AI prompt injection.
  String toAiContextString() {
    final parts = <String>[];
    if (name.trim().isNotEmpty) {
      parts.add('User Name: ${name.trim()}');
    }
    if (age != null && age! > 0) {
      parts.add('Age: $age');
    }
    if (designation.trim().isNotEmpty) {
      parts.add('Role/Designation: ${designation.trim()}');
    }
    if (hobbies.isNotEmpty) {
      parts.add('Hobbies & Interests: ${hobbies.join(', ')}');
    }

    if (parts.isEmpty) return '';
    return 'USER PROFILE CONTEXT:\n'
        '${parts.map((p) => '- $p').join('\n')}\n'
        'Tailor the routine schedule, breaks, and task style appropriately for this user profile.';
  }
}
