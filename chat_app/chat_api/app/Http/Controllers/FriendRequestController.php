<?php

namespace App\Http\Controllers;

use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Http\Request;

class FriendRequestController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'receiver_id' => 'required|exists:users,id|different:'.$request->user()->id,
        ]);

        $senderId = $request->user()->id;
        $receiverId = $request->receiver_id;

        $existing = FriendRequest::where('sender_id', $senderId)
            ->where('receiver_id', $receiverId)
            ->first();

        if ($existing) {
            return response()->json([
                'message' => 'Friend request already sent.',
            ], 409);
        }

        $friendRequest = FriendRequest::create([
            'sender_id' => $senderId,
            'receiver_id' => $receiverId,
            'status' => 'pending',
        ]);

        return response()->json([
            'message' => 'Friend request sent.',
            'data' => $friendRequest,
        ], 201);
    }

    public function index(Request $request)
    {
        $requests = FriendRequest::where('receiver_id', $request->user()->id)
            ->where('status', 'pending')
            ->with('sender:id,name,email')
            ->get();

        return response()->json(['data' => $requests]);
    }

    public function update(Request $request, FriendRequest $friendRequest)
    {
        $request->validate([
            'status' => 'required|in:accepted,declined',
        ]);

        abort_unless(
            $friendRequest->receiver_id === $request->user()->id,
            403
        );

        $friendRequest->update([
            'status' => $request->status,
        ]);

        return response()->json(['data' => $friendRequest]);
    }

    public function friends(Request $request)
    {
        $userId = $request->user()->id;

        $friendIds = FriendRequest::query()
            ->where('status', 'accepted')
            ->where(function ($query) use ($userId) {
                $query->where('sender_id', $userId)
                    ->orWhere('receiver_id', $userId);
            })
            ->get(['sender_id', 'receiver_id'])
            ->map(function ($friendRequest) use ($userId) {
                return $friendRequest->sender_id === $userId
                    ? $friendRequest->receiver_id
                    : $friendRequest->sender_id;
            })
            ->unique()
            ->values();

        $friends = User::whereIn('id', $friendIds)
            ->get(['id', 'name', 'email']);

        return response()->json(['data' => $friends]);
    }

    public function destroyFriend(Request $request, $friendId)
    {
        $userId = $request->user()->id;

        $deleted = FriendRequest::where('status', 'accepted')
            ->where(function ($query) use ($userId, $friendId) {
                $query->where(function ($query) use ($userId, $friendId) {
                    $query->where('sender_id', $userId)
                        ->where('receiver_id', $friendId);
                })->orWhere(function ($query) use ($userId, $friendId) {
                    $query->where('sender_id', $friendId)
                        ->where('receiver_id', $userId);
                });
            })
            ->delete();

        if ($deleted === 0) {
            return response()->json([
                'message' => 'Friendship not found.',
            ], 404);
        }

        return response()->json([
            'message' => 'Friend removed successfully.',
        ]);
    }
}
