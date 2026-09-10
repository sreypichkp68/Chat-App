<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ConversationMember extends Model
{
    protected $fillable = ['conversation_id', 'user_id', 'role', 'last_read_message_id', 'joined_at'];

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function lastReadMessage()
    {
        return $this->belongsTo(Message::class, 'last_read_message_id');
    }
}
