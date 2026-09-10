import 'package:chat_app/feature/group/presentation/screen/adduser_group.dart';
import 'package:chat_app/feature/searchusers/domain/usecase/search_user_usecase.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

class AboutUser extends StatelessWidget {
  final String participantName;

  const AboutUser({super.key, required this.participantName});

  /// Helper method to display the modal bottom sheet easily from anywhere
  static void show(BuildContext context, {required String participantName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(
        0xFF1E1E1E,
      ), // Dark background matching design
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AboutUser(participantName: participantName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat info Section
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Chat info',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.perm_media_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Media, links and files',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Actions Section
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Actions',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.notifications_off_outlined,
                    title: 'Mute $participantName',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Notifications & sounds',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.group_add_outlined,
                    title: 'Create group chat with $participantName',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlocProvider(
                            create: (context) => SearchUsersBloc(
                              GetIt.instance<SearchUsersUsecase>(),
                            ),
                            child: AdduserGroup(
                              initialSelectedUser: participantName,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.file_download_outlined,
                    title: 'Auto-save photos',
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Off', style: TextStyle(color: Colors.grey)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () {},
                  ),
                  _buildDivider(),

                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.ios_share_outlined,
                    title: 'Share contact',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: Color(0xFF3A3A3C),
      height: 1,
      indent: 52,
      endIndent: 0,
    );
  }
}
