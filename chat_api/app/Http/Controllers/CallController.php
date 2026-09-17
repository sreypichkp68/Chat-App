<?php

namespace App\Http\Controllers;

use App\Events\CallAccepted;
use App\Events\CallDeclined;
use App\Events\CallInvited;
use App\Events\MessageSent;
use App\Models\Call;
use App\Models\Conversation;
use BoogieFromZk\AgoraToken\RtcTokenBuilder2;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Laravel\Reverb\Loggers\Log;

class CallController extends Controller
{
    public function show(Request $request, string $callId)
    {
        $call = Call::where('call_id', $callId)->firstOrFail();
        abort_unless(in_array((int) $request->user()->id,
            [(int) $call->caller_id, (int) $call->callee_id], true), 403);

        return response()->json(['call_id' => $call->call_id,
            'status' => $call->status, 'ended_at' => $call->ended_at]);
    }

    public function invite(Request $request)
    {
        $data = $request->validate([
            'callId' => 'required|string',
            'callerId' => 'required|integer',
            'callerName' => 'required|string',
            'calleeId' => 'required|integer',
            'channelName' => 'required|string',
            'isVideo' => 'required|boolean',
            'groupId' => 'nullable|integer|exists:conversations,id',
            'groupName' => 'nullable|string',
        ]);

        abort_unless((int) $data['callerId'] === (int) $request->user()->id, 403);
        if (isset($data['groupId'])) {
            $group = Conversation::findOrFail($data['groupId']);
            abort_unless($group->type === 'group', 422);
            abort_unless($group->members()->where('user_id', $data['callerId'])->exists(), 403);
            abort_unless($group->members()->where('user_id', $data['calleeId'])->exists(), 403);
            abort_if((int) $data['callerId'] === (int) $data['calleeId'], 422);
        }

        Call::create([
            'call_id' => $data['callId'],
            'caller_id' => $data['callerId'],
            'callee_id' => $data['calleeId'],
            'group_id' => $data['groupId'] ?? null,
            'channel_name' => $data['channelName'],
            'type' => $data['isVideo'] ? 'video' : 'audio',
            'status' => 'ringing',
            'started_at' => now(),
        ]);
        try {
            broadcast(new CallInvited($data))->toOthers();
            Log::info('BROADCAST SUCCESS', $data);
        } catch (\Throwable $e) {
            Log::error('BROADCAST FAILED: '.$e->getMessage(), [
                'exception' => $e,
            ]);
        }

        return response()->json(['status' => 'ok']);
    }

    public function accept(Request $request)
    {
        $data = $request->validate([
            'callId' => 'required|string',
            'peerId' => 'required|integer',
        ]);

        $call = Call::where('call_id', $data['callId'])->firstOrFail();
        abort_unless((int) $call->callee_id === (int) $request->user()->id, 403);
        abort_unless((int) $data['peerId'] === (int) $call->caller_id, 403);
        $call->update(['status' => 'accepted']);

        // The event is addressed to the peer's private channel, so do not use
        // toOthers(): it can suppress delivery when an X-Socket-ID is present.
        broadcast(new CallAccepted($data['callId'], (string) $data['peerId']));

        return response()->json(['status' => 'ok']);
    }

    public function decline(Request $request)
    {
        $data = $request->validate([
            'callId' => 'required|string',
            'peerId' => 'required|integer',
        ]);

        $call = Call::where('call_id', $data['callId'])->firstOrFail();
        abort_unless((int) $call->callee_id === (int) $request->user()->id, 403);
        abort_unless((int) $data['peerId'] === (int) $call->caller_id, 403);
        $call->update([
            'status' => 'declined',
            'ended_at' => now(),
        ]);

        // This is already sent only to the caller's private channel.
        broadcast(new CallDeclined($data['callId'], (string) $data['peerId']));

        return response()->json(['status' => 'ok']);
    }

    public function end(Request $request, string $callId)
{
    $data = $request->validate([
        'status' => 'required|in:accepted,declined,ended,missed',
    ]);

    return DB::transaction(function () use ($callId, $data, $request) {
        $initialCall = Call::where('call_id', $callId)->firstOrFail();
        // Serialize all hangups in one group channel before checking whether
        // the last participant has left. Each invite has its own call row.
        $group = $initialCall->group_id === null ? null
            : Conversation::whereKey($initialCall->group_id)->lockForUpdate()->first();
        $call = Call::where('call_id', $callId)->lockForUpdate()->firstOrFail();

        $currentUserId = (int) $request->user()->id;
        $callerId = (int) $call->caller_id;
        $calleeId = (int) $call->callee_id;
        abort_unless(in_array($currentUserId, [$callerId, $calleeId], true), 403,
            'You are not a participant in this call.');

        $peerId = $currentUserId === $callerId ? $calleeId : $callerId;
        // Publish after the final state is committed, including on retries.
        // A retry must still dismiss the peer's ringing screen even when
        // the history record was already written by an earlier request.
        DB::afterCommit(function () use ($callId, $peerId) {
            broadcast(new \App\Events\CallEnded($callId, (string) $peerId));
        });

        if ($call->group_id !== null) {
            $updates = [];
            if ($call->ended_at === null) {
                $updates['status'] = $data['status'];
                $updates['ended_at'] = now();
            }
            if ($currentUserId === $callerId && $call->caller_left_at === null) {
                $updates['caller_left_at'] = now();
            }
            if ($updates) {
                $call->update($updates);
            }
            $message = $group ? $this->recordGroupCallHistory($group, $call) : null;

            return response()->json(['call' => $call, 'message' => $message]);
        }

        if ($call->ended_at !== null) {
            $existingMessage = Conversation::betweenUsers($call->caller_id, $call->callee_id)
                ?->messages()
                ->where('message_type', 'call_log')
                ->whereJsonContains('metadata->call_id', $call->call_id)
                ->latest()
                ->first();

            return response()->json(['call' => $call, 'message' => $existingMessage]);
        }

        $call->update([
            'status' => $data['status'],
            'ended_at' => now(),
        ]);

        $duration = ($call->started_at && $call->ended_at)
            ? $call->ended_at->diffInSeconds($call->started_at)
            : null;

        $conversation = $call->group_id === null
            ? Conversation::betweenUsers($call->caller_id, $call->callee_id)
            : null;
        $message = null;

        if ($conversation) {
            $message = $conversation->messages()->create([
                'sender_id' => $call->caller_id,
                'message_type' => 'call_log',
                'metadata' => [
                    'call_id' => $call->call_id,
                    'call_type' => $call->type,
                    'status' => $call->status,
                    'duration_seconds' => $duration,
                    'caller_id' => $call->caller_id,
                ],
            ]);

            broadcast(new MessageSent($message))->toOthers();
        }

        return response()->json(['call' => $call, 'message' => $message]);
    });
}

    private function recordGroupCallHistory(Conversation $group, Call $call): ?\App\Models\Message
    {
        $calls = Call::where('group_id', $group->id)
            ->where('channel_name', $call->channel_name);
        if ((clone $calls)->whereNull('ended_at')->exists()) {
            return null;
        }
        if ((clone $calls)->whereNotNull('caller_left_at')->doesntExist()) {
            return null;
        }

        $existing = $group->messages()
            ->where('message_type', 'call_log')
            ->where('metadata->channel_name', $call->channel_name)
            ->first();
        if ($existing) {
            return $existing;
        }

        $firstCall = (clone $calls)->orderBy('started_at')->firstOrFail();
        $lastEndedAt = (clone $calls)->max('ended_at');
        $duration = $firstCall->started_at && $lastEndedAt
            ? $firstCall->started_at->diffInSeconds($lastEndedAt)
            : null;
        $hadParticipant = (clone $calls)->where('status', 'ended')->exists();
        $message = $group->messages()->create([
            'sender_id' => $firstCall->caller_id,
            'message_type' => 'call_log',
            'metadata' => [
                'group_id' => $group->id,
                'channel_name' => $call->channel_name,
                'call_type' => $call->type,
                'status' => $hadParticipant ? 'ended' : 'missed',
                'duration_seconds' => $duration,
                'caller_id' => $firstCall->caller_id,
            ],
        ]);
        DB::afterCommit(function () use ($message) {
            broadcast(new MessageSent($message));
        });

        return $message;
    }

    /**
     * Issues an Agora RTC token for the given channel/uid pair, so the
     * client can join a Secured-mode channel. Called right before
     * joinChannel() on both the caller and callee side (see
     * CallBloc._fetchToken in the Flutter app).
     */
    public function token(Request $request)
    {
        $data = $request->validate([
            'channelName' => 'required|string',
            'uid' => 'required|integer',
        ]);

        $token = RtcTokenBuilder2::buildTokenWithUid(
            config('services.agora.app_id'),
            config('services.agora.app_certificate'),
            $data['channelName'],
            $data['uid'],
            RtcTokenBuilder2::ROLE_PUBLISHER,
            3600, // 1 hour — plenty for a call setup window
        );

        return response()->json(['token' => $token]);
    }
}
