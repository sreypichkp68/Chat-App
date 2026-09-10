import 'package:chat_app/feature/message/presentation/screen/conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:chat_app/feature/group/presentation/bloc/group_bloc.dart';
import 'package:chat_app/feature/group/presentation/bloc/group_event.dart';
import 'package:chat_app/feature/group/presentation/bloc/group_state.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_event.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user.state.dart';

class AdduserGroup extends StatefulWidget {
  final String? initialSelectedUser;

  const AdduserGroup({super.key, this.initialSelectedUser});

  @override
  State<AdduserGroup> createState() => _AdduserGroupState();
}

class _AdduserGroupState extends State<AdduserGroup> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Stores selected users' data
  final Map<String, dynamic> _selectedUsers = {};

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleUserSelection(dynamic user) {
    setState(() {
      if (_selectedUsers.containsKey(user.id)) {
        _selectedUsers.remove(user.id);
      } else {
        _selectedUsers[user.id] = user;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Helper getter for the UI horizontal list
    final selectedUsersList = _selectedUsers.values.toList();

    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupSuccess) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ConversationScreen(
                conversationId: state.group.id, // int
                participantId: state.group.id.toString(), // String
                participantName:
                    state.group.title, // String (uses 'title' from GroupEntity)
              ),
            ),
          );
        } else if (state is GroupFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New group'),
          actions: [
            TextButton(
              onPressed: _selectedUsers.isEmpty
                  ? null
                  : () {
                      final groupName = _groupNameController.text.trim().isEmpty
                          ? _selectedUsers.values.map((u) => u.name).join(', ')
                          : _groupNameController.text.trim();

                      final memberIds = _selectedUsers.keys.toList();

                      context.read<GroupBloc>().add(
                        CreateGroupRequested(
                          name: groupName,
                          memberIds: memberIds,
                        ),
                      );
                    },
              child: const Text('Create'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Name Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Group name (optional)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                ),
              ),
            ),

            // Search Field linked to SearchUsersBloc
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (query) {
                    context.read<SearchUsersBloc>().add(
                      SearchQueryChanged(query),
                    );
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Selected Users Horizontal List
            if (selectedUsersList.isNotEmpty) ...[
              SizedBox(
                height: 90,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedUsersList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final user = selectedUsersList[index];
                    return Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFF34C471),
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _toggleUserSelection(user),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Search Results Area
            Expanded(
              child: BlocBuilder<SearchUsersBloc, SearchUsersState>(
                builder: (context, state) {
                  if (state is SearchUsersLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    );
                  }

                  if (state is SearchUsersError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  if (state is SearchUsersLoaded) {
                    if (state.results.isEmpty) {
                      return const Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: state.results.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Color(0xFF2C2C2E),
                        height: 1,
                        indent: 72,
                      ),
                      itemBuilder: (context, index) {
                        final user = state.results[index];
                        final isSelected = _selectedUsers.containsKey(user.id);

                        return ListTile(
                          onTap: () => _toggleUserSelection(user),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF34C471),
                            child: Text(
                              user.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  }

                  return const Center(
                    child: Text(
                      'Search users from database',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
