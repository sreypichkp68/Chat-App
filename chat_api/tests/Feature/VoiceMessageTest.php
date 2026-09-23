<?php

namespace Tests\Feature;

use App\Events\MessageSent;
use App\Models\Conversation;
use App\Models\ConversationMember;
use App\Models\User;
use CloudinaryLabs\CloudinaryLaravel\CloudinaryEngine;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Mockery;
use Tests\TestCase;

class VoiceMessageTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null]);
        DB::purge('sqlite');
        $this->artisan('migrate', ['--force' => true])->assertExitCode(0);
        Event::fake([MessageSent::class]);
    }

    private function chat(): array
    {
        $sender = User::factory()->create();
        $recipient = User::factory()->create();
        $chat = Conversation::create(['type' => 'direct', 'created_by' => $sender->id]);
        foreach ([$sender, $recipient] as $user) {
            ConversationMember::create(['conversation_id' => $chat->id, 'user_id' => $user->id]);
        }
        return [$sender, $recipient, $chat];
    }

    public function test_voice_upload_is_saved_and_broadcast_to_recipient(): void
    {
        [$sender, $recipient, $chat] = $this->chat();
        $cloud = Mockery::mock(CloudinaryEngine::class);
        $cloud->shouldReceive('uploadVideo')->once()
            ->with(Mockery::type('string'), ['folder' => 'chat-app/voice-messages'])->andReturnSelf();
        $cloud->shouldReceive('getSecurePath')->once()->andReturn('https://example.com/voice.m4a');
        $this->app->instance(CloudinaryEngine::class, $cloud);

        $response = $this->actingAs($sender, 'sanctum')->postJson(
            '/api/conversations/'.$chat->id.'/messages', [
                'message_type' => 'audio', 'audio_duration' => 4,
                'file' => UploadedFile::fake()->create('voice.m4a', 12, 'audio/mp4'),
            ]);
        $response->assertCreated()->assertJsonPath('message_type', 'audio')
            ->assertJsonPath('metadata.audio_url', 'https://example.com/voice.m4a')
            ->assertJsonPath('metadata.duration_seconds', 4);
        Event::assertDispatched(MessageSent::class, function ($event) use ($recipient) {
            return collect($event->broadcastOn())->contains(
                fn ($channel) => $channel->name === 'private-inbox.'.$recipient->id);
        });
        $this->actingAs($recipient, 'sanctum')->getJson('/api/conversations/'.$chat->id.'/messages')
            ->assertOk()->assertJsonPath('data.0.metadata.audio_url', 'https://example.com/voice.m4a');
    }

    public function test_missing_invalid_and_oversized_audio_are_rejected(): void
    {
        [$sender, , $chat] = $this->chat();
        $url = '/api/conversations/'.$chat->id.'/messages';
        $this->actingAs($sender, 'sanctum')->postJson($url, [
            'message_type' => 'audio', 'audio_duration' => 4,
        ])->assertUnprocessable();
        foreach ([
            UploadedFile::fake()->create('note.txt', 1, 'text/plain'),
            UploadedFile::fake()->create('voice.m4a', 10241, 'audio/mp4'),
        ] as $file) {
            $this->postJson($url, ['message_type' => 'audio', 'audio_duration' => 4,
                'file' => $file])->assertUnprocessable();
        }
        $this->postJson($url, ['message_type' => 'audio', 'audio_duration' => 301,
            'file' => UploadedFile::fake()->create('voice.m4a', 12, 'audio/mp4')])
            ->assertUnprocessable();
        $this->assertDatabaseCount('messages', 0);
    }

    public function test_outsider_cannot_upload_and_cloud_failure_creates_no_message(): void
    {
        [$sender, , $chat] = $this->chat();
        $url = '/api/conversations/'.$chat->id.'/messages';
        $payload = ['message_type' => 'audio', 'audio_duration' => 4,
            'file' => UploadedFile::fake()->create('voice.m4a', 12, 'audio/mp4')];
        $this->actingAs(User::factory()->create(), 'sanctum')->postJson($url, $payload)
            ->assertForbidden();
        $cloud = Mockery::mock(CloudinaryEngine::class);
        $cloud->shouldReceive('uploadVideo')->once()->andThrow(new \RuntimeException('Upload unavailable'));
        $this->app->instance(CloudinaryEngine::class, $cloud);
        $this->actingAs($sender, 'sanctum')->postJson($url, $payload)->assertStatus(502);
        $this->assertDatabaseCount('messages', 0);
        Event::assertNotDispatched(MessageSent::class);
    }
}
