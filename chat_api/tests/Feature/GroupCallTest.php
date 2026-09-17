<?php

namespace Tests\Feature;

use App\Events\CallInvited;
use App\Events\CallEnded;
use App\Events\MessageSent;
use App\Models\Call;
use App\Models\Conversation;
use App\Models\ConversationMember;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class GroupCallTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null]);
        DB::purge('sqlite');
        $this->artisan('migrate', ['--force' => true])->assertExitCode(0);
        Event::fake([CallInvited::class, CallEnded::class, MessageSent::class]);
    }

    public function test_group_history_is_written_once_after_all_invites_end(): void
    {
        $caller = User::factory()->create();
        $callee = User::factory()->create();
        $secondCallee = User::factory()->create();
        $group = Conversation::create([
            'type' => 'group', 'title' => 'Friends', 'created_by' => $caller->id,
        ]);
        foreach ([$caller, $callee, $secondCallee] as $user) {
            ConversationMember::create([
                'conversation_id' => $group->id,
                'user_id' => $user->id,
                'role' => 'member',
            ]);
        }

        $payload = [
            'callId' => 'group-1', 'callerId' => $caller->id,
            'callerName' => $caller->name, 'calleeId' => $callee->id,
            'channelName' => 'group-call-1', 'isVideo' => true,
            'groupId' => $group->id, 'groupName' => $group->title,
        ];
        $this->actingAs($caller, 'sanctum')
            ->postJson('/api/calls/invite', $payload)->assertOk();
        $payload['callId'] = 'group-1-second';
        $payload['calleeId'] = $secondCallee->id;
        $this->actingAs($caller, 'sanctum')
            ->postJson('/api/calls/invite', $payload)->assertOk();
        $this->assertSame($group->id, Call::where('call_id', 'group-1')->firstOrFail()->group_id);
        Event::assertDispatched(CallInvited::class,
            fn ($event) => $event->payload['groupId'] === $group->id);

        $this->actingAs($callee, 'sanctum')
            ->postJson('/api/calls/group-1/end', ['status' => 'ended'])->assertOk();
        $this->assertNotNull(Call::where('call_id', 'group-1')->firstOrFail()->ended_at);
        $this->assertDatabaseMissing('messages', ['message_type' => 'call_log']);

        $this->actingAs($secondCallee, 'sanctum')
            ->postJson('/api/calls/group-1-second/end', ['status' => 'ended'])
            ->assertOk()
            ->assertJsonPath('message', null);
        $this->assertDatabaseMissing('messages', ['message_type' => 'call_log']);
        $this->actingAs($caller, 'sanctum')
            ->postJson('/api/calls/group-1/end', ['status' => 'ended'])
            ->assertOk()
            ->assertJsonPath('message.metadata.group_id', $group->id);

        $this->assertSame(1, $group->messages()->where('message_type', 'call_log')->count());
        $this->assertSame('group-call-1',
            $group->messages()->firstOrFail()->metadata['channel_name']);
        Event::assertDispatchedTimes(MessageSent::class, 1);
    }

    public function test_group_call_rejects_nonmembers_and_spoofed_caller(): void
    {
        $caller = User::factory()->create();
        $callee = User::factory()->create();
        $outsider = User::factory()->create();
        $group = Conversation::create([
            'type' => 'group', 'title' => 'Friends', 'created_by' => $caller->id,
        ]);
        foreach ([$caller, $callee] as $user) {
            ConversationMember::create([
                'conversation_id' => $group->id,
                'user_id' => $user->id,
                'role' => 'member',
            ]);
        }
        $payload = [
            'callId' => 'group-2', 'callerId' => $caller->id,
            'callerName' => $caller->name, 'calleeId' => $outsider->id,
            'channelName' => 'group-call-2', 'isVideo' => false,
            'groupId' => $group->id,
        ];
        $this->actingAs($caller, 'sanctum')
            ->postJson('/api/calls/invite', $payload)->assertForbidden();
        $payload['calleeId'] = $callee->id;
        $this->actingAs($outsider, 'sanctum')
            ->postJson('/api/calls/invite', $payload)->assertForbidden();
        $this->assertDatabaseCount('calls', 0);
    }

    public function test_caller_hangup_waits_for_the_last_member(): void
    {
        $caller = User::factory()->create();
        $callee = User::factory()->create();
        $secondCallee = User::factory()->create();
        $group = Conversation::create([
            'type' => 'group', 'title' => 'Friends', 'created_by' => $caller->id,
        ]);
        Call::create([
            'call_id' => 'group-3',
            'caller_id' => $caller->id,
            'callee_id' => $callee->id,
            'group_id' => $group->id,
            'channel_name' => 'group-call-3',
            'type' => 'audio',
            'status' => 'ringing',
            'started_at' => now(),
        ]);
        Call::create([
            'call_id' => 'group-3-second',
            'caller_id' => $caller->id,
            'callee_id' => $secondCallee->id,
            'group_id' => $group->id,
            'channel_name' => 'group-call-3',
            'type' => 'audio',
            'status' => 'ringing',
            'started_at' => now(),
        ]);

        $this->actingAs($caller, 'sanctum')
            ->postJson('/api/calls/group-3/end', ['status' => 'ended'])->assertOk();
        $this->assertDatabaseMissing('messages', ['message_type' => 'call_log']);
        $this->actingAs($callee, 'sanctum')
            ->postJson('/api/calls/group-3-second/end', ['status' => 'ended'])->assertForbidden();
        $this->actingAs($secondCallee, 'sanctum')
            ->postJson('/api/calls/group-3-second/end', ['status' => 'ended'])->assertOk();
        $this->assertSame(1, $group->messages()->where('message_type', 'call_log')->count());
    }
}
