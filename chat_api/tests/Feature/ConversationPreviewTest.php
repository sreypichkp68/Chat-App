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
