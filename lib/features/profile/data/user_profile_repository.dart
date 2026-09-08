import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/user_profile.dart';

/// Repository for persisting and retrieving user profile data from SharedPreferences.
class UserProfileRepository {
  static const String keyName = 'user_profile_name';
  static const String keyAge = 'user_profile_age';
  static const String keyDesignation = 'user_profile_designation';
  static const String keyHobbies = 'user_profile_hobbies';
  static const String keyAvatarPath = 'user_profile_avatar_path';

  final SharedPreferences _prefs;

  UserProfileRepository(this._prefs);

  static Future<UserProfileRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfileRepository(prefs);
  }

  UserProfile getProfile() {
    final name = _prefs.getString(keyName) ?? '';
    final age = _prefs.getInt(keyAge);
    final designation = _prefs.getString(keyDesignation) ?? 'Student';
    final hobbies = _prefs.getStringList(keyHobbies) ?? [];
    final avatarPath = _prefs.getString(keyAvatarPath);

    return UserProfile(
      name: name,
      age: age,
      designation: designation,
      hobbies: hobbies,
      avatarPath: avatarPath,
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(keyName, profile.name);
    if (profile.age != null) {
      await _prefs.setInt(keyAge, profile.age!);
    } else {
      await _prefs.remove(keyAge);
    }
    await _prefs.setString(keyDesignation, profile.designation);
    await _prefs.setStringList(keyHobbies, profile.hobbies);
    if (profile.avatarPath != null && profile.avatarPath!.isNotEmpty) {
      await _prefs.setString(keyAvatarPath, profile.avatarPath!);
    } else {
      await _prefs.remove(keyAvatarPath);
    }
  }
}
