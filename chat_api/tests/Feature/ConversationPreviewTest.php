<?php

namespace Tests\Feature;

use App\Models\Call;
use App\Models\Conversation;
use App\Models\ConversationMember;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ConversationPreviewTest extends TestCase
{
    public function test_removing_chat_preserves_friendship_and_other_members_and_can_be_reopened(): void
    {
        $owner = User::factory()->create();
        $friend = User::factory()->create();
        $outsider = User::factory()->create();
        $friendship = \App\Models\FriendRequest::create([
            'sender_id' => $owner->id, 'receiver_id' => $friend->id, 'status' => 'accepted',
        ]);
        $conversation = Conversation::create(['type' => 'direct', 'created_by' => $owner->id]);
        foreach ([$owner, $friend] as $user) {
            ConversationMember::create([
                'conversation_id' => $conversation->id, 'user_id' => $user->id, 'role' => 'member',
            ]);
        }
        $message = $conversation->messages()->create([
            'sender_id' => $friend->id, 'content' => 'Hello', 'message_type' => 'text',
        ]);
        $url = '/api/conversations/'.$conversation->id;
        $this->actingAs($outsider, 'sanctum')->deleteJson($url)->assertNotFound();
        $this->actingAs($owner, 'sanctum')->deleteJson($url)->assertOk();
        $this->getJson('/api/conversations')->assertExactJson([]);
        $this->assertDatabaseHas('friend_requests', ['id' => $friendship->id, 'status' => 'accepted']);
        $this->assertDatabaseHas('messages', ['id' => $message->id]);
        $this->actingAs($friend, 'sanctum')->getJson('/api/conversations')
            ->assertJsonPath('0.id', $conversation->id);
        $this->actingAs($owner, 'sanctum')->postJson('/api/conversations', ['receiver_id' => $friend->id])
            ->assertOk()->assertJsonPath('conversation.id', $conversation->id);
        $this->getJson('/api/conversations')->assertJsonPath('0.id', $conversation->id);
        $this->deleteJson($url)->assertOk();
        $conversation->messages()->create([
            'sender_id' => $friend->id, 'content' => 'Hello again', 'message_type' => 'text',
        ]);
        $this->getJson('/api/conversations')->assertJsonPath('0.id', $conversation->id);
    }

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null,
        ]);
        DB::purge('sqlite');
        $this->artisan('migrate', ['--force' => true])->assertExitCode(0);
    }

    public function test_old_declined_call_does_not_appear_in_a_new_empty_chat(): void
    {
        $caller = User::factory()->create();
        $callee = User::factory()->create();

        Call::create([
            'call_id' => 'old-declined-call',
            'caller_id' => $caller->id,
            'callee_id' => $callee->id,
            'channel_name' => 'old-channel',
            'status' => 'declined',
            'started_at' => now()->subDay(),
            'ended_at' => now()->subDay(),
        ]);

        $conversation = Conversation::create([
            'type' => 'direct',
            'created_by' => $caller->id,
        ]);
        foreach ([$caller, $callee] as $user) {
            ConversationMember::create([
                'conversation_id' => $conversation->id,
                'user_id' => $user->id,
                'role' => 'member',
            ]);
        }

        $this->actingAs($caller, 'sanctum')
            ->getJson('/api/conversations')
            ->assertOk()
            ->assertJsonPath('0.id', $conversation->id)
            ->assertJsonPath('0.last_message', null);
    }
}
