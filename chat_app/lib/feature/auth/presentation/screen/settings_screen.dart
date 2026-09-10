import 'dart:convert';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/core/service/token_storage.dart';
import 'package:chat_app/feature/auth/presentation/screen/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  late Future<_UserProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<_UserProfile> _loadProfile() async {
    final storage = sl<TokenStorage>();
    final name = await storage.getUserName();
    final email = await storage.getUserEmail();
    if ((name ?? '').isNotEmpty || (email ?? '').isNotEmpty) {
      return _UserProfile(name: name ?? '', email: email ?? '');
    }

    final token = await storage.getToken();
    if (token == null || token.isEmpty) return const _UserProfile(name: '', email: '');

    try {
      final response = await sl<http.Client>().get(
        Uri.parse(ApiEntpoint.currentUser),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return const _UserProfile(name: '', email: '');
      final body = jsonDecode(response.body);
      final root = body is Map<String, dynamic> ? body : <String, dynamic>{};
      final data = root['data'];
      final user = root['user'] is Map<String, dynamic>
          ? root['user'] as Map<String, dynamic>
          : data is Map<String, dynamic> && data['user'] is Map<String, dynamic>
              ? data['user'] as Map<String, dynamic>
              : data is Map<String, dynamic> ? data : root;
      final profile = _UserProfile(
        name: user['name'] as String? ?? user['username'] as String? ?? '',
        email: user['email'] as String? ?? '',
      );
      await storage.saveUserProfile(name: profile.name, email: profile.email);
      if (user['id'] != null) await storage.saveUserId(user['id'].toString());
      return profile;
    } catch (_) {
      return const _UserProfile(name: '', email: '');
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    final storage = sl<TokenStorage>();
    final token = await storage.getToken();
    try {
      if (token != null && token.isNotEmpty) {
        await sl<http.Client>().post(
          Uri.parse('${ApiEntpoint.url}/logout'),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        );
      }
    } finally {
      await storage.deleteToken();
      await storage.deleteUserProfile();
      await storage.deleteUserId();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title settings are coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF7F7F8);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: FutureBuilder<_UserProfile>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data ?? const _UserProfile(name: '', email: '');
            final displayName = profile.name.isNotEmpty ? profile.name : 'User';
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Text('Profile', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF17171A), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileCard(name: displayName, email: profile.email),
                      const SizedBox(height: 18),
                      _SettingsSection(title: 'Account', children: [
                        _SettingsTile(icon: Icons.person_outline_rounded, title: 'Manage Profile', onTap: () => _showComingSoon('Manage profile')),
                        _SettingsTile(icon: Icons.lock_outline_rounded, title: 'Password & Security', onTap: () => _showComingSoon('Password & security')),
                        _SettingsTile(icon: Icons.notifications_none_rounded, title: 'Notifications', onTap: () => _showComingSoon('Notifications')),
                        _SettingsTile(icon: Icons.language_rounded, title: 'Language', value: 'English', onTap: () => _showComingSoon('Language')),
                      ]),
                      const SizedBox(height: 18),
                      _SettingsSection(title: 'Preferences', children: [
                        _SettingsTile(icon: Icons.article_outlined, title: 'About Us', onTap: () => _showComingSoon('About us')),
                        _SettingsTile(icon: Icons.contrast_outlined, title: 'Theme', value: 'Light', onTap: () => _showComingSoon('Theme')),
                        _SettingsTile(icon: Icons.calendar_today_outlined, title: 'Appointments', onTap: () => _showComingSoon('Appointments')),
                      ]),
                      const SizedBox(height: 18),
                      _SettingsSection(title: 'Support', children: [
                        _SettingsTile(icon: Icons.help_outline_rounded, title: 'Help Center', onTap: () => _showComingSoon('Help center')),
                        _SettingsTile(icon: Icons.logout_rounded, title: _isLoggingOut ? 'Logging out...' : 'Log out', isDestructive: true, showChevron: false, onTap: _isLoggingOut ? null : _logout),
                      ]),
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
  const _ProfileCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        CircleAvatar(radius: 30, backgroundColor: const Color(0xFFEEE9FF), child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF5B47B8), fontSize: 22, fontWeight: FontWeight.w700))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF222226), fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email.isNotEmpty ? email : 'No email address', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98989E), fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 1, bottom: 8), child: Text(title, style: const TextStyle(color: Color(0xFF97979D), fontSize: 13, fontWeight: FontWeight.w500))),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(children: children)),
    ]);
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, this.value, this.onTap, this.isDestructive = false, this.showChevron = true});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive ? const Color(0xFFD64B4B) : const Color(0xFF2B2B30);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 11),
            Expanded(child: Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
            if (value != null) Text(value!, style: const TextStyle(color: Color(0xFF929299), fontSize: 12)),
            if (value != null && showChevron) const SizedBox(width: 10),
            if (showChevron) Icon(Icons.chevron_right_rounded, size: 20, color: isDestructive ? textColor : const Color(0xFF323238)),
          ]),
        ),
      ),
    );
  }
}

class _UserProfile {
  final String name;
  final String email;

  const _UserProfile({required this.name, required this.email});
}
