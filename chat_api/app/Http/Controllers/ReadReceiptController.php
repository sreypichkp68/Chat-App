<?php

namespace App\Http\Controllers;

use App\Models\ConversationMember;
use App\Models\Message;
use Illuminate\Http\Request;

class ReadReceiptController extends Controller
{
    public function index(Request $request, $conversation)
    {
        ConversationMember::where('conversation_id', $conversation)
            ->where('user_id', $request->user()->id)->firstOrFail();

        return response()->json(['data' => ConversationMember::where('conversation_id', $conversation)
            ->get(['user_id', 'last_read_message_id'])]);
    }

    public function store(Request $request, $conversation)
    {
        $member = ConversationMember::where('conversation_id', $conversation)
            ->where('user_id', $request->user()->id)->firstOrFail();
        $data = $request->validate(['message_id' => 'required|integer|min:1']);
        $message = Message::where('conversation_id', $conversation)
            ->whereKey($data['message_id'])->firstOrFail();

        // A delayed request must never move the read position backwards.
        ConversationMember::whereKey($member->id)
            ->where(function ($query) use ($message) {
                $query->whereNull('last_read_message_id')
                    ->orWhere('last_read_message_id', '<', $message->id);
            })->update(['last_read_message_id' => $message->id]);

        return response()->json(['last_read_message_id' => $member->fresh()->last_read_message_id]);
    }
}
