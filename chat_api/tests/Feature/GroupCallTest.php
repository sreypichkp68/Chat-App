<?php

namespace Tests\Feature;

use App\Events\CallInvited;
use App\Events\CallEnded;
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
        Event::fake([CallInvited::class, CallEnded::class]);
    }

    public function test_member_can_invite_another_member_and_end_without_direct_call_log(): void
    {
        $caller = User::factory()->create();
        $callee = User::factory()->create();
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
            'callId' => 'group-1', 'callerId' => $caller->id,
            'callerName' => $caller->name, 'calleeId' => $callee->id,
            'channelName' => 'group-call-1', 'isVideo' => true,
            'groupId' => $group->id, 'groupName' => $group->title,
        ];
        $this->actingAs($caller, 'sanctum')
            ->postJson('/api/calls/invite', $payload)->assertOk();
        $this->assertSame($group->id, Call::where('call_id', 'group-1')->firstOrFail()->group_id);
        Event::assertDispatched(CallInvited::class,
            fn ($event) => $event->payload['groupId'] === $group->id);

        $this->actingAs($callee, 'sanctum')
            ->postJson('/api/calls/group-1/end', ['status' => 'ended'])->assertOk();
        $this->assertNotNull(Call::where('call_id', 'group-1')->firstOrFail()->ended_at);
        $this->assertDatabaseMissing('messages', ['message_type' => 'call_log']);
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
}
