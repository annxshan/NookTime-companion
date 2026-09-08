import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import 'account_sync_screen.dart';
import 'widgets/appearance_bottom_sheet.dart';

/// App Settings Screen for Nooktime.
/// Houses core settings tiles including Appearance & Theme.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PREFERENCES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Settings Card Container
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) {
                    final controller = ThemeController.instance;
                    final seedColor = controller.seedColor;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: seedColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.palette_outlined,
                          color: seedColor,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Appearance & Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${controller.themeModeName} · Customise styling',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: seedColor,
                              border: Border.all(
                                color: isDark ? Colors.white24 : Colors.black12,
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () => AppearanceThemeBottomSheet.show(context),
                    );
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeController.instance.seedColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.cloud_sync_rounded,
                      color: ThemeController.instance.seedColor,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Account & Cloud Sync',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Backup, restore, & sync Google account data',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountSyncScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
