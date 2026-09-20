import 'package:flutter/material.dart';

class MemberTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const MemberTile({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(name[0].toUpperCase())),
      title: Text(name),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      onTap: onTap,
    );
  }
}
