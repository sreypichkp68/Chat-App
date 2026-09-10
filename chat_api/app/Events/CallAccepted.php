<?php
// app/Events/CallAccepted.php
namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

class CallAccepted implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public string $callId, public string $peerId) {}

    public function broadcastOn(): Channel
    {
        return new PrivateChannel('calls.' . $this->peerId);
    }

    public function broadcastAs(): string
    {
        return 'CallAccepted';
    }

    public function broadcastWith(): array
    {
        return ['callId' => $this->callId];
    }
}