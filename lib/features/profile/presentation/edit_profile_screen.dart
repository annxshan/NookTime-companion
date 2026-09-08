import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/user_profile_repository.dart';
import '../domain/models/user_profile.dart';

/// Screen allowing the user to edit their profile details (Avatar Photo, Name, Age, Designation, Hobbies).
/// Styled to match the exact glassmorphic & dark gradient design system of the Routine Dashboard.
class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final UserProfileRepository repository;
  final String? photoUrl;

  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.repository,
    this.photoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  final TextEditingController _hobbyInputController = TextEditingController();

  late String _selectedDesignation;
  late List<String> _hobbies;
  String? _customAvatarPath;

  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> _designationOptions = [
    'Student',
    'Employee',
    'Worker',
    'Freelancer',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController = TextEditingController(
      text: widget.profile.age != null ? widget.profile.age.toString() : '',
    );
    _selectedDesignation = _designationOptions.contains(widget.profile.designation)
        ? widget.profile.designation
        : 'Student';
    _hobbies = List<String>.from(widget.profile.hobbies);
    _customAvatarPath = widget.profile.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _hobbyInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _customAvatarPath = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select image: $e')),
        );
      }
    }
  }

  void _showImagePickerModal() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeController.instance.seedColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeController.instance.seedColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_customAvatarPath != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('Remove Custom Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _customAvatarPath = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    final ageVal = int.tryParse(_ageController.text.trim());
    final updatedProfile = UserProfile(
      name: _nameController.text.trim(),
      age: ageVal,
      designation: _selectedDesignation,
      hobbies: _hobbies,
      avatarPath: _customAvatarPath,
    );

    await widget.repository.saveProfile(updatedProfile);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFF1E293B),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00D2D3), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Profile updated successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _addHobby() {
    final text = _hobbyInputController.text.trim();
    if (text.isNotEmpty && !_hobbies.contains(text)) {
      setState(() {
        _hobbies.add(text);
        _hobbyInputController.clear();
      });
      HapticFeedback.selectionClick();
    }
  }

  void _removeHobby(String hobby) {
    setState(() {
      _hobbies.remove(hobby);
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = ThemeController.instance.seedColor;

        final displayName = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'User';

        ImageProvider? avatarImageProvider;
        if (_customAvatarPath != null && _customAvatarPath!.isNotEmpty) {
          avatarImageProvider = FileImage(File(_customAvatarPath!));
        } else if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
          avatarImageProvider = NetworkImage(widget.photoUrl!);
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            scrolledUnderElevation: 2,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Glassmorphic Avatar Header Container ─────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? primaryColor.withValues(alpha: 0.3) : Colors.grey.shade200,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showImagePickerModal,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: isDark ? const Color(0xFF161228) : Colors.white,
                                backgroundImage: avatarImageProvider,
                                child: avatarImageProvider == null
                                    ? Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showImagePickerModal,
                      icon: Icon(Icons.edit_rounded, size: 15, color: primaryColor),
                      label: Text(
                        'Change Profile Photo',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Form Input Section Card ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Input
                    Text(
                      'DISPLAY NAME',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: primaryColor, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Age & Designation Selection
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AGE',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 24',
                                  prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFFFF7675), size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROLE / DESIGNATION',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedDesignation,
                                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.work_outline_rounded, color: primaryColor, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                ),
                                items: _designationOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt,
                                    child: Text(opt, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedDesignation = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Hobbies Section
                    Text(
                      'HOBBIES & INTERESTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hobbyInputController,
                            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Add a hobby (e.g. Fitness, Reading)',
                              prefixIcon: Icon(Icons.sports_esports_outlined, color: primaryColor, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            ),
                            onSubmitted: (_) => _addHobby(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: _addHobby,
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    ),
                    if (_hobbies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _hobbies.map((hobby) {
                          return Chip(
                            label: Text(hobby, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 15),
                            onDeleted: () => _removeHobby(hobby),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: primaryColor.withValues(alpha: 0.15),
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
                            labelStyle: TextStyle(color: primaryColor),
                            deleteIconColor: primaryColor,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save Profile Action Button
              Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _isSaving
                      ? null
                      : LinearGradient(
                          colors: [
                            primaryColor,
                            Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor),
                          ],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isSaving ? 'Saving Profile...' : 'Save Profile Changes',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
