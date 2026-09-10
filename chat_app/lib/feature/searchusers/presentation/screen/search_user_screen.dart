import 'package:chat_app/feature/message/presentation/widget/chat_color.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user.state.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_bloc.dart';
import 'package:chat_app/feature/searchusers/presentation/bloc/search_user_event.dart';
import 'package:chat_app/feature/searchusers/presentation/widget/user_search_tile.dart';
import 'package:chat_app/core/service/injection_container.dart';
import 'package:chat_app/feature/friends/data/datasource/friend_request_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchUserScreen extends StatelessWidget {
  const SearchUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.paper,
      appBar: AppBar(
        backgroundColor: ChatColors.paper,
        elevation: 0,
        title: const Text('New Chat'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                style: ChatType.body,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  hintStyle: ChatType.body.copyWith(color: ChatColors.inkFaint),
                  prefixIcon: const Icon(Icons.search, color: ChatColors.inkFaint),
                  filled: true,
                  fillColor: ChatColors.clay.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) =>
                    context.read<SearchUsersBloc>().add(SearchQueryChanged(q)),
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchUsersBloc, SearchUsersState>(
                builder: (context, state) {
                  return switch (state) {
                    SearchUsersInitial() =>
                      const Center(child: Text('Search for someone to start chatting')),
                    SearchUsersLoading() => const Center(child: CircularProgressIndicator()),
                    SearchUsersError(:final message) => Center(child: Text('Error: $message')),
                    SearchUsersLoaded(:final results) => results.isEmpty
                        ? const Center(child: Text('No users found'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: Color(0x1223303D)),
                            itemBuilder: (context, i) => UserSearchTile(
                              key: ValueKey(results[i].id),
                              user: results[i],
                              onTap: () {
                                // TODO: navigate into a new/existing conversation
                              },
                              onAddFriend: () =>
                                  sl<FriendRequestRemoteDatasource>()
                                      .sendFriendRequest(
                                        receiverId: results[i].id,
                                      ),
                            ),
                          ),
                    // TODO: Handle this case.
                    SearchUsersState() => throw UnimplementedError(),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
