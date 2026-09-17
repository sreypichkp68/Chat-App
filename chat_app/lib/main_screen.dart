import 'package:chat_app/feature/message/presentation/screen/chat_screen.dart';
import 'package:chat_app/feature/profile/presentation/screen/settings_screen.dart';
import 'package:chat_app/feature/group/presentation/screen/group_screen.dart';
import 'package:chat_app/feature/call/presentation/screen/call_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List screen = [
    ChatScreen(),
    const CallHistoryScreen(),
    const GroupScreen(),
    const SettingsScreen(),
  ];
  int indexPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screen[indexPage],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: indexPage,
        onTap: (value) {
          setState(() {
            indexPage = value;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Char"),
          BottomNavigationBarItem(icon: Icon(Icons.phone), label: "Call"),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            label: "Group",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
        ],
      ),
    );
  }
}
