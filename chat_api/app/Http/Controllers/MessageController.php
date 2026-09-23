<?php

namespace App\Http\Controllers;

use App\Events\MessageSent;
use App\Models\Message;
use App\Models\ConversationMember;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Laravel\Reverb\Loggers\Log;

class MessageController extends Controller
{
    public function index($conversationId)
    {
        $messages = Message::where('conversation_id', $conversationId)
            ->with(['sender:id,name,avatar_url', 'parentMessage'])
            ->orderBy('created_at', 'desc')
            ->orderBy('id', 'desc')
            ->paginate(50);

        return response()->json($messages);
    }

    public function store(Request $request, $conversationId)
    {
        abort_unless(ConversationMember::where('conversation_id', $conversationId)
            ->where('user_id', $request->user()->id)->exists(), 403);

        $request->validate([
            'message_type' => 'required|in:text,image,audio,file,call_log',
            'content' => 'nullable|string',
            'file' => $request->input('message_type') === 'audio'
                ? 'required|file|mimes:m4a,mp4,mp3,wav,aac,ogg,webm|max:10240'
                : 'nullable|file|max:20480',
            'audio_duration' => 'required_if:message_type,audio|nullable|integer|min:1|max:300',
            'reply_to_message_id' => 'nullable|exists:messages,id',
            'metadata' => 'nullable|array', // new
        ]);

        // Start with whatever metadata the client already sent (e.g. Cloudinary imageUrl).
        $metadata = $request->input('metadata', []) ?? [];

        if ($request->message_type === 'audio') {
            try {
                $uploaded = cloudinary()->uploadVideo(
                    $request->file('file')->getRealPath(),
                    ['folder' => 'chat-app/voice-messages']
                );
                $url = $uploaded->getSecurePath();
                if (!is_string($url) || !str_starts_with($url, 'https://')) {
                    throw new \RuntimeException('Audio upload did not return a secure URL.');
                }
                $metadata = ['audio_url' => $url];
            } catch (\Throwable $error) {
                report($error);
                return response()->json(['message' => 'Could not upload voice message. Please try again.'], 502);
            }
        } elseif ($request->hasFile('file')) {
            $path = $request->file('file')->store("chats/{$conversationId}", 'public');
            $metadata['file_url'] = Storage::url($path);
            $metadata['file_name'] = $request->file('file')->getClientOriginalName();
        }

        if ($request->has('audio_duration')) {
            $metadata['duration_seconds'] = (int) $request->audio_duration;
        }

        $message = Message::create([
            'conversation_id' => $conversationId,
            'sender_id' => $request->user()->id,
            'content' => $request->input('content'),
            'message_type' => $request->message_type,
            'metadata' => ! empty($metadata) ? $metadata : null,
            'reply_to_message_id' => $request->reply_to_message_id,
        ]);

        broadcast(new MessageSent($message))->toOthers();

        return response()->json($message->load('sender:id,name,avatar_url'), 201);
    }

    public function update(Request $request, $id)
    {
        $message = Message::findOrFail($id);

        if ($message->sender_id !== $request->user()->id) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $request->validate(['content' => 'required|string']);
        if (!empty($message->metadata['is_unsent'])) {
            return response()->json(['message' => 'An unsent message cannot be edited.'], 409);
        }

        $message->content = $request->input('content');
        $metadata = $message->metadata ?? [];
        $metadata['is_edited'] = true;
        $message->metadata = $metadata;
        $message->save();

        return response()->json(['message' => 'Message updated successfully', 'data' => $message]);
    }

    public function destroy(Request $request, $id)
    {
        $message = Message::findOrFail($id);

        if ($message->sender_id !== $request->user()->id) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        if (! empty($message->metadata['file_url'])) {
            Storage::disk('public')->delete(str_replace('/storage/', '', $message->metadata['file_url']));
        }

        $message->content = 'Unsend Message';
        $message->message_type = 'text';
        $message->metadata = ['is_unsent' => true];
        $message->reply_to_message_id = null;
        $message->save();

        return response()->json(['message' => 'Message deleted successfully']);
    }

    // MessageController.php
    // MessageController.php
  public function uploadImage(Request $request)
{
    $request->validate([
        'file' => 'required|image|max:10240',
    ]);

    try {
        $uploadedFile = cloudinary()->upload(
            $request->file('file')->getRealPath(),
            [
                'folder' => 'chat-app/messages',
            ]
        );

        return response()->json([
            'data' => [
                'url' => $uploadedFile->getSecurePath(),
            ],
        ]);
    } catch (\Throwable $e) {
        return response()->json([
            'message' => 'Cloudinary upload failed',
            'error' => $e->getMessage(),
            'class' => get_class($e),
        ], 500);
    }
}
}
