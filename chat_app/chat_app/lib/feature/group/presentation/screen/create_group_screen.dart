import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/group_bloc.dart';
import '../bloc/group_event.dart';
import '../bloc/group_state.dart';
import '../widget/member_tile.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<Map<String, dynamic>> friendsList; // Pass user's friends list here

  const CreateGroupScreen({super.key, required this.friendsList});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _titleController = TextEditingController();
  final List<int> _selectedUserIds = [];

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedUserIds.contains(id)) {
        _selectedUserIds.remove(id);
      } else {
        _selectedUserIds.add(id);
      }
    });
  }

  void _submitGroup() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group title')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    context.read<GroupBloc>().add(
      CreateGroupSubmitted(
        title: _titleController.text.trim(),
        memberIds: _selectedUserIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Group')),
      body: BlocConsumer<GroupBloc, GroupState>(
        listener: (context, state) {
          if (state is GroupSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Group "${state.group.title}" created!')),
            );
            Navigator.pop(context, state.group);
          } else if (state is GroupFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error)));
          }
        },
        builder: (context, state) {
          if (state is GroupLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Members:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.friendsList.length,
                    itemBuilder: (context, index) {
                      final friend = widget.friendsList[index];
                      final isSelected = _selectedUserIds.contains(
                        friend['id'],
                      );
                      return MemberTile(
                        name: friend['name'],
                        isSelected: isSelected,
                        onTap: () => _toggleSelection(friend['id']),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitGroup,
                  child: const Text('Create Group'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
