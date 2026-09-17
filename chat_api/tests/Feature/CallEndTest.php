<?php
namespace Tests\Feature;

use App\Events\CallEnded;
use App\Events\CallDeclined;
use App\Events\MessageSent;
use App\Models\Call;
use App\Models\Conversation;
use App\Models\ConversationMember;
use App\Models\User;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class CallEndTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null]);
        DB::purge('sqlite');
        $this->artisan('migrate', ['--force' => true])->assertExitCode(0);
        Event::fake([CallEnded::class]);
    }

    public function test_caller_hangup_broadcasts_to_callee_including_retries(): void
    {
        [$caller, $callee, $call] = $this->makeCall();
        for ($attempt = 0; $attempt < 2; $attempt++) {
            $this->actingAs($caller, 'sanctum')
                ->postJson('/api/calls/'.$call->call_id.'/end', ['status' => 'missed'])
                ->assertOk();
        }
        Event::assertDispatchedTimes(CallEnded::class, 2);
        Event::assertDispatched(CallEnded::class, function ($event) use ($callee, $call) {
            return $event instanceof ShouldBroadcastNow
                && $event->broadcastAs() === 'CallEnded'
                && $event->broadcastOn()->name === 'private-calls.'.$callee->id
                && $event->broadcastWith() === ['callId' => $call->call_id];
        });
    }

    public function test_callee_hangup_targets_caller(): void
    {
        [$caller, $callee, $call] = $this->makeCall();
        $this->actingAs($callee, 'sanctum')
            ->postJson('/api/calls/'.$call->call_id.'/end', ['status' => 'ended'])
            ->assertOk();
        Event::assertDispatched(CallEnded::class,
            fn ($event) => $event->peerId === (string) $caller->id);
    }

    public function test_nonparticipant_cannot_end_a_call(): void
    {
        [, , $call] = $this->makeCall();
        $this->actingAs(User::factory()->create(), 'sanctum')
            ->postJson('/api/calls/'.$call->call_id.'/end', ['status' => 'ended'])
            ->assertForbidden();
        $this->assertNull($call->fresh()->ended_at);
        Event::assertNotDispatched(CallEnded::class);
    }

    public function test_status_reports_hangup_only_to_participants(): void
    {
        [$caller, $callee, $call] = $this->makeCall();
        $this->actingAs($callee, 'sanctum')->getJson('/api/calls/'.$call->call_id)
            ->assertOk()->assertJson(['status' => 'ringing', 'ended_at' => null]);
        $call->update(['status' => 'missed', 'ended_at' => now()]);
        $this->actingAs($callee, 'sanctum')->getJson('/api/calls/'.$call->call_id)
            ->assertOk()->assertJson(['status' => 'missed', 'call_id' => $call->call_id]);
        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson('/api/calls/'.$call->call_id)->assertForbidden();
    }

    public function test_decline_records_one_call_log_even_if_end_arrives_later(): void
    {
        Event::fake([CallEnded::class, CallDeclined::class, MessageSent::class]);
        [$caller, $callee, $call] = $this->makeCall();
        $conversation = Conversation::create(['type' => 'direct', 'created_by' => $caller->id]);
        foreach ([$caller, $callee] as $user) {
            ConversationMember::create([
                'conversation_id' => $conversation->id,
                'user_id' => $user->id,
                'role' => 'member',
            ]);
        }

        $this->actingAs($callee, 'sanctum')->postJson('/api/calls/decline', [
            'callId' => $call->call_id,
            'peerId' => $caller->id,
        ])->assertOk();
        $this->actingAs($callee, 'sanctum')->postJson('/api/calls/'.$call->call_id.'/end', [
            'status' => 'declined',
        ])->assertOk();

        $logs = $conversation->messages()->where('message_type', 'call_log')->get();
        $this->assertCount(1, $logs);
        $this->assertSame('declined', $logs->first()->metadata['status']);
        Event::assertDispatchedTimes(MessageSent::class, 1);
    }

    private function makeCall(): array
    {
        $caller = User::factory()->create();
        $callee = User::factory()->create();
        $call = Call::create([
            'call_id' => 'test-call', 'caller_id' => $caller->id,
            'callee_id' => $callee->id, 'channel_name' => 'test-channel',
            'status' => 'ringing', 'started_at' => now(),
        ]);
        return [$caller, $callee, $call];
    }
}
