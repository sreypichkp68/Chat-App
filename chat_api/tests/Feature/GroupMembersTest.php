<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\ConversationMember;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class GroupMembersTest extends TestCase
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

    public function test_admin_can_view_and_add_members_from_group_chat(): void
    {
        $admin = User::factory()->create();
        $newMember = User::factory()->create();
        $group = Conversation::create([
            'type' => 'group',
            'title' => 'Friends',
            'created_by' => $admin->id,
        ]);
        ConversationMember::create([
            'conversation_id' => $group->id,
            'user_id' => $admin->id,
            'role' => 'admin',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/groups/'.$group->id)
            ->assertOk()
            ->assertJsonPath('conversation.users.0.id', $admin->id);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/groups/'.$group->id.'/members', [
                'member_ids' => [$newMember->id],
            ])
            ->assertOk()
            ->assertJsonCount(2, 'conversation.users');
    }

    public function test_non_member_cannot_view_group_members(): void
    {
        $admin = User::factory()->create();
        $group = Conversation::create([
            'type' => 'group',
            'title' => 'Friends',
            'created_by' => $admin->id,
        ]);

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson('/api/groups/'.$group->id)
            ->assertForbidden();
    }
}
