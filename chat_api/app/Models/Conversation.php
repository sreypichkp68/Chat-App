<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class Conversation extends Model
{
    protected $fillable = ['type', 'title', 'avatar_url', 'created_by'];

    public function members()
    {
        return $this->hasMany(ConversationMember::class);
    }

    public function users()
    {
        return $this->belongsToMany(User::class, 'conversation_members')
            ->withPivot('role', 'last_read_message_id', 'joined_at')
            ->withTimestamps();
    }
    // Conversation.php
    public static function betweenUsers(int $userId1, int $userId2): ?self
    {
        return static::query()
            ->whereExists(function ($query) use ($userId1) {
                $query->select(DB::raw(1))
                    ->from('conversation_members')
                    ->whereColumn('conversations.id', 'conversation_members.conversation_id')
                    ->where('user_id', $userId1);
            })
            ->whereExists(function ($query) use ($userId2) {
                $query->select(DB::raw(1))
                    ->from('conversation_members')
                    ->whereColumn('conversations.id', 'conversation_members.conversation_id')
                    ->where('user_id', $userId2);
            })
            ->whereRaw(
                '(select count(*) from conversation_members where conversations.id = conversation_members.conversation_id) = ?',
                [2]
            )
            ->first();
    }

    public function messages()
    {
        return $this->hasMany(Message::class);
    }

    public function lastMessage()
    {
        return $this->hasOne(Message::class)->latestOfMany();
    }
}
