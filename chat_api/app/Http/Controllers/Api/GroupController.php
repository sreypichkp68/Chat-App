<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class GroupController extends Controller
{
    //
    /**
     * Create a new group conversation.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'avatar_url' => 'nullable|string|url',
            'member_ids' => 'required|array|min:1',
            'member_ids.*' => 'exists:users,id',
        ]);

        $authUserId = $request->user()->id;

        // Prevent adding oneself twice if included in member_ids
        $memberIds = array_unique(array_merge($validated['member_ids'], [$authUserId]));

        $conversation = DB::transaction(function () use ($validated, $authUserId, $memberIds) {
            // 1. Create the group conversation
            $group = Conversation::create([
                'type' => 'group',
                'title' => $validated['title'],
                'avatar_url' => $validated['avatar_url'] ?? null,
                'created_by' => $authUserId,
            ]);

            // 2. Prepare pivot data (creator gets 'admin' role)
            $membersData = [];
            foreach ($memberIds as $id) {
                $membersData[$id] = [
                    'role' => ($id === $authUserId) ? 'admin' : 'member',
                    'joined_at' => now(),
                ];
            }

            // 3. Attach all users to the conversation
            $group->users()->attach($membersData);

            return $group;
        });

        return response()->json([
            'message' => 'Group created successfully',
            'conversation' => $conversation->load('users:id,name,avatar_url'),
        ], 201);
    }

    /**
     * Add one or more users to an existing group.
     */
    public function addMember(Request $request, Conversation $group)
    {
        if ($group->type !== 'group') {
            return response()->json(['message' => 'This conversation is not a group'], 422);
        }

        $validated = $request->validate([
            'member_ids' => 'required|array|min:1',
            'member_ids.*' => 'exists:users,id',
        ]);

        $authUserId = $request->user()->id;

        $isAdmin = $group->users()
            ->wherePivot('user_id', $authUserId)
            ->wherePivot('role', 'admin')
            ->exists();

        if (!$isAdmin) {
            return response()->json(['message' => 'Only admins can add members'], 403);
        }

        $existingIds = $group->users()->pluck('users.id')->toArray();
        $newIds = array_diff($validated['member_ids'], $existingIds);

        if (empty($newIds)) {
            return response()->json(['message' => 'User(s) already in group'], 409);
        }

        $membersData = [];
        foreach ($newIds as $id) {
            $membersData[$id] = [
                'role' => 'member',
                'joined_at' => now(),
            ];
        }

        $group->users()->attach($membersData);

        return response()->json([
            'message' => 'Member(s) added successfully',
            'conversation' => $group->load('users:id,name,avatar_url'),
        ], 200);
    }

    /**
     * Remove a user from the group.
     */
    public function removeMember(Request $request, Conversation $group, int $userId)
    {
        if ($group->type !== 'group') {
            return response()->json(['message' => 'This conversation is not a group'], 422);
        }

        $authUserId = $request->user()->id;

        $isAdmin = $group->users()
            ->wherePivot('user_id', $authUserId)
            ->wherePivot('role', 'admin')
            ->exists();

        if (!$isAdmin && $authUserId !== $userId) {
            return response()->json(['message' => 'Not authorized to remove this member'], 403);
        }

        if (!$group->users()->where('users.id', $userId)->exists()) {
            return response()->json(['message' => 'User is not in this group'], 404);
        }

        $group->users()->detach($userId);

        return response()->json(['message' => 'Member removed successfully'], 200);
    }
    
}
