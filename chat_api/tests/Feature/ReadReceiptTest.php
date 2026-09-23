<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\ConversationMember;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ReadReceiptTest extends TestCase
{
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

    public function test_receipts_require_explicit_read_and_never_move_backwards(): void
    {
        $sender = User::factory()->create();
        $reader = User::factory()->create();
        $chat = Conversation::create(['type' => 'direct', 'created_by' => $sender->id]);
        foreach ([$sender, $reader] as $user) {
            ConversationMember::create(['conversation_id' => $chat->id, 'user_id' => $user->id]);
        }
        $text = $chat->messages()->create(['sender_id' => $sender->id, 'content' => 'Hello', 'message_type' => 'text']);
        $image = $chat->messages()->create(['sender_id' => $sender->id, 'content' => 'photo.jpg', 'message_type' => 'image']);
        $url = '/api/conversations/'.$chat->id.'/read-receipts';

        $this->actingAs($reader, 'sanctum')->getJson('/api/conversations/'.$chat->id.'/messages')->assertOk();
        $this->assertDatabaseHas('conversation_members', ['conversation_id' => $chat->id, 'user_id' => $reader->id, 'last_read_message_id' => null]);
        $this->postJson($url, ['message_id' => $image->id])->assertOk()->assertJsonPath('last_read_message_id', $image->id);
        $this->postJson($url, ['message_id' => $text->id])->assertOk()->assertJsonPath('last_read_message_id', $image->id);
        $this->actingAs($sender, 'sanctum')->getJson($url)->assertOk()->assertJsonFragment([
            'user_id' => $reader->id, 'last_read_message_id' => $image->id,
        ]);
        $this->assertDatabaseHas('conversation_members', ['conversation_id' => $chat->id, 'user_id' => $sender->id, 'last_read_message_id' => null]);
    }

    public function test_outsiders_and_messages_from_another_chat_are_rejected(): void
    {
        $member = User::factory()->create();
        $outsider = User::factory()->create();
        $chat = Conversation::create(['type' => 'direct', 'created_by' => $member->id]);
        ConversationMember::create(['conversation_id' => $chat->id, 'user_id' => $member->id]);
        $other = Conversation::create(['type' => 'direct', 'created_by' => $outsider->id]);
        $message = $other->messages()->create(['sender_id' => $outsider->id, 'content' => 'Private', 'message_type' => 'text']);
        $url = '/api/conversations/'.$chat->id.'/read-receipts';

        $this->getJson($url)->assertUnauthorized();
        $this->actingAs($outsider, 'sanctum')->getJson($url)->assertNotFound();
        $this->postJson($url, ['message_id' => $message->id])->assertNotFound();
        $this->actingAs($member, 'sanctum')->postJson($url, ['message_id' => $message->id])->assertNotFound();
        $this->postJson($url, ['message_id' => -1])->assertUnprocessable();
        $this->assertDatabaseHas('conversation_members', ['conversation_id' => $chat->id, 'user_id' => $member->id, 'last_read_message_id' => null]);
    }
}
