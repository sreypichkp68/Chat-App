<?php

namespace App\Events;

use App\Models\Message;
use App\Models\ConversationMember;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Message $message;

    public function __construct(Message $message)
    {
        $this->message = $message;
    }

    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel('conversation.' . $this->message->conversation_id),
        ];

        $recipientIds = ConversationMember::where('conversation_id', $this->message->conversation_id)
            ->where('user_id', '!=', $this->message->sender_id)
            ->pluck('user_id');

        foreach ($recipientIds as $userId) {
            $channels[] = new PrivateChannel('inbox.' . $userId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'MessageSent';
    }

    public function broadcastWith(): array
    {
        return [
            'message' => $this->message->load('sender:id,name,avatar_url'),
        ];
    }
}
