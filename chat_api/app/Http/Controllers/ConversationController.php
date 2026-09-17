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

    $conversations->each(function ($conversation) use ($user) {
        $lastMessage = $conversation->lastMessage;
        $lastCall = $conversation->type === 'direct' ? $conversation->lastCall() : null;

        $lastMessageAt = $lastMessage?->created_at;
        $lastCallAt = $lastCall?->started_at;

        // Call is more recent than the last text message → show call as preview
        if ($lastCall && (!$lastMessage || $lastCallAt->gt($lastMessageAt))) {
            $conversation->unsetRelation('lastMessage');
            $conversation->setAttribute('last_message', [
                'message_type' => 'call',
                'content' => $this->formatCallPreview($lastCall, $user->id),
                'created_at' => $lastCall->started_at,
                'sender_id' => $lastCall->caller_id,
            ]);
        }
    });

    return response()->json($conversations);
}

private function formatCallPreview($call, int $currentUserId): string
{
    if (in_array($call->status, ['missed', 'no_answer'])) {
        return $call->status === 'missed' ? 'Missed call' : 'No answer';
    }
    if ($call->status === 'declined') {
        return 'Declined call';
    }
    if ($call->ended_at && $call->started_at) {
        $seconds = $call->ended_at->diffInSeconds($call->started_at);
        return sprintf('Call · %d:%02d', intdiv($seconds, 60), $seconds % 60);
    }
    return 'Call';
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