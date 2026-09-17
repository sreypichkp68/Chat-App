<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

class CallInvited implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public array $payload) {}

    public function broadcastOn(): Channel
{
    return new PrivateChannel('calls.'.$this->payload['calleeId']);
}

    public function broadcastAs(): string
    {
        return 'CallInvited';
    }

    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
