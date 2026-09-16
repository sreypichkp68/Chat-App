<?php

namespace Tests\Feature;

use App\Events\MessageSent;
use App\Models\Conversation;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MessageNotificationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null]);
        DB::purge('sqlite');
        $this->artisan('migrate', ['--force' => true])->assertExitCode(0);
    }

    public function test_messages_reach_all_recipient_inboxes_but_not_sender_or_outsider(): void
    {
        $sender = User::factory()->create();
        $recipient = User::factory()->create();
        $otherRecipient = User::factory()->create();
        User::factory()->create();
        $conversation = Conversation::create(['type' => 'group', 'created_by' => $sender->id]);
        $conversation->users()->attach([$sender->id, $recipient->id, $otherRecipient->id]);

        foreach (['text', 'image'] as $type) {
            $message = $conversation->messages()->create([
                'sender_id' => $sender->id, 'content' => 'hello', 'message_type' => $type,
            ]);
            $event = new MessageSent($message);
            $this->assertEqualsCanonicalizing([
                'private-conversation.'.$conversation->id,
                'private-inbox.'.$recipient->id,
                'private-inbox.'.$otherRecipient->id,
            ], array_map(fn ($channel) => $channel->name, $event->broadcastOn()));
            $this->assertSame($sender->name, $event->broadcastWith()['message']->sender->name);
        }
    }

    public function test_inbox_authorization_only_allows_its_owner(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $authorize = \Illuminate\Support\Facades\Broadcast::getChannels()['inbox.{userId}'];
        $this->assertTrue($authorize($user, (string) $user->id));
        $this->assertFalse($authorize($other, (string) $user->id));
    }
}
