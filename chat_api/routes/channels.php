<?php

use App\Models\Conversation;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Log;

Broadcast::channel(
    'conversation.{conversationId}',
    function ($user, $conversationId) {
        return Conversation::where('id', $conversationId)
            ->whereHas(
                'members',
                fn ($query) =>
                    $query->where('user_id', $user->id)
            )
            ->exists();
    }
);
Broadcast::channel('calls.{userId}', function ($user, $userId) {

    Log::warning('CALL CHANNEL AUTH', [
        'authenticated_user' => $user?->id,
        'requested_user' => $userId,
    ]);

    return true;
});