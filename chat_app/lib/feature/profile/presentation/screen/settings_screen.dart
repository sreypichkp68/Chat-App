import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/core/theme/theme_controller.dart';
import 'package:chat_app/feature/auth/presentation/screen/login_screen.dart';
import 'package:chat_app/feature/profile/data/datasource/profile_remote_data_source.dart';
import 'package:chat_app/feature/profile/domain/entity/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  late Future<UserProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = ProfileRemoteDataSource(
      client: sl<http.Client>(),
      storage: sl<TokenStorage>(),
    ).load();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    final storage = sl<TokenStorage>();
    final token = await storage.getToken();
    try {
      if (token != null && token.isNotEmpty) {
        await sl<http.Client>().post(
          Uri.parse('${ApiEntpoint.url}/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {
      // Clear this device's session even when the server is unavailable.
    }
    await stopCallListening();
    await storage.deleteToken();
    await storage.deleteUserProfile();
    await storage.deleteUserId();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _editProfile() async {
    final profile = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          datasource: ProfileRemoteDataSource(
            client: sl<http.Client>(),
            storage: sl<TokenStorage>(),
          ),
        ),
      ),
    );
    if (!mounted || profile == null) return;
    setState(() {
      _profile = Future.value(profile);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title settings are coming soon.')));
  }

  Future<void> _chooseTheme() async {
    final current = ThemeController.mode.value;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Theme'),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in [ThemeMode.light, ThemeMode.dark])
              ListTile(
                leading: Icon(
                  choice == ThemeMode.light
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                title: Text(choice == ThemeMode.light ? 'Light' : 'Dark'),
                trailing: current == choice ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(dialogContext, choice),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await ThemeController.setMode(selected);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save theme preference.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).brightness == Brightness.dark
        ? scheme.surface
        : const Color(0xFFF7F7F8);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data ?? UserProfile.empty;
            final displayName = profile.name.isNotEmpty ? profile.name : 'User';
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileCard(
                        name: displayName,
                        email: profile.email,
                        avatarUrl: profile.avatarUrl,
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: 'Account',
                        children: [
                          _SettingsTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Manage Profile',
                            onTap: _editProfile,
                          ),
                          _SettingsTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Password & Security',
                            onTap: () => _showComingSoon('Password & security'),
                          ),
                          _SettingsTile(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            onTap: () => _showComingSoon('Notifications'),
                          ),
                          _SettingsTile(
                            icon: Icons.language_rounded,
                            title: 'Language',
                            value: 'English',
                            onTap: () => _showComingSoon('Language'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: 'Preferences',
                        children: [
                          _SettingsTile(
                            icon: Icons.article_outlined,
                            title: 'About Us',
                            onTap: () => _showComingSoon('About us'),
                          ),
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: ThemeController.mode,
                            builder: (context, mode, _) => _SettingsTile(
                              icon: Icons.contrast_outlined,
                              title: 'Theme',
                              value: mode == ThemeMode.dark ? 'Dark' : 'Light',
                              onTap: _chooseTheme,
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.calendar_today_outlined,
                            title: 'Appointments',
                            onTap: () => _showComingSoon('Appointments'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: 'Support',
                        children: [
                          _SettingsTile(
                            icon: Icons.help_outline_rounded,
                            title: 'Help Center',
                            onTap: () => _showComingSoon('Help center'),
                          ),
                          _SettingsTile(
                            icon: Icons.logout_rounded,
                            title: _isLoggingOut ? 'Logging out...' : 'Log out',
                            isDestructive: true,
                            showChevron: false,
                            onTap: _isLoggingOut ? null : _logout,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email, this.avatarUrl});

  final String? avatarUrl;

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.primaryContainer,
            foregroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? NetworkImage(
                    Uri.parse(ApiEntpoint.url).resolve(avatarUrl!).toString(),
                  )
                : null,
            onForegroundImageError: avatarUrl != null && avatarUrl!.isNotEmpty
                ? (_, stack) {}
                : null,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isNotEmpty ? email : 'No email address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = isDestructive ? scheme.error : scheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              if (value != null && showChevron) const SizedBox(width: 10),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDestructive ? textColor : scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
