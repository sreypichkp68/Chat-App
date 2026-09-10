<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = [
        'conversation_id',
        'sender_id',
        'content',
        'message_type',
        'metadata',
        'reply_to_message_id',
    ];

    protected $casts = [
        'metadata' => 'array', // Automatically handles JSON string to PHP array conversion
    ];

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function parentMessage()
    {
        return $this->belongsTo(Message::class, 'reply_to_message_id');
    }
}
