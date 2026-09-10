<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ConversationMember;
use Illuminate\Http\Request;

class ConversationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $conversations = Conversation::whereHas('members', function ($q) use ($user) {
            $q->where('user_id', $user->id);
        })
        ->with(['lastMessage', 'members.user:id,name,avatar_url'])
        ->get();

        return response()->json($conversations);
    }

    public function store(Request $request)
    {
        $request->validate([
            'receiver_id' => 'required|exists:users,id',
        ]);

        $authUserId = $request->user()->id;
        $receiverId = $request->receiver_id;

        if ($authUserId == $receiverId) {
            return response()->json(['error' => 'You cannot chat with yourself.'], 400);
        }

        $existingConversation = Conversation::where('type', 'direct')
            ->whereHas('members', function ($q) use ($authUserId) {
                $q->where('user_id', $authUserId);
            })
            ->whereHas('members', function ($q) use ($receiverId) {
                $q->where('user_id', $receiverId);
            })
            ->first();

        if ($existingConversation) {
            return response()->json([
                'message' => 'Conversation already exists',
                'conversation' => $existingConversation->load('members.user:id,name,avatar_url')
            ]);
        }

        $conversation = Conversation::create([
            'type' => 'direct',
            'created_by' => $authUserId,
        ]);

        ConversationMember::create([
            'conversation_id' => $conversation->id,
            'user_id' => $authUserId,
            'role' => 'admin',
        ]);

        ConversationMember::create([
            'conversation_id' => $conversation->id,
            'user_id' => $receiverId,
            'role' => 'member',
        ]);

        return response()->json([
            'message' => 'Conversation created successfully',
            'conversation' => $conversation->load('members.user:id,name,avatar_url')
        ], 201);
    }
}