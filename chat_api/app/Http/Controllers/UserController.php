<?php

namespace App\Http\Controllers;

use App\Models\FriendRequest;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UserController extends Controller
{
    public function show(Request $request)
    {
        return response()->json($request->user());
    }

    public function update(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'name' => 'sometimes|string|max:255',
            'status_message' => 'sometimes|nullable|string|max:255',
            'avatar' => 'sometimes|image|mimes:jpeg,png,jpg,gif|max:5000',
        ]);

        if ($request->hasFile('avatar')) {
            try {
                $uploadedFile = cloudinary()->upload(
                    $request->file('avatar')->getRealPath(),
                    ['folder' => 'chat-app/avatars']
                );
                $avatarUrl = $uploadedFile->getSecurePath();
                if (!is_string($avatarUrl) || !str_starts_with($avatarUrl, 'https://')) {
                    throw new \RuntimeException('Avatar upload did not return a secure URL.');
                }
            } catch (\Throwable $error) {
                report($error);

                return response()->json([
                    'message' => 'Could not upload your profile photo. Please try again.',
                ], 502);
            }
            $user->avatar_url = $avatarUrl;
        }

        if ($request->has('name')) {
            $user->name = $request->name;
        }
        if ($request->has('status_message')) {
            $user->status_message = $request->status_message;
        }

        $user->save();

        return response()->json(['message' => 'Profile updated successfully', 'user' => $user]);
    }

    public function destroy(Request $request)
    {
        $user = $request->user();
        if ($user->avatar_url && str_starts_with($user->avatar_url, '/storage/avatars/')) {
            Storage::disk('public')->delete(substr($user->avatar_url, strlen('/storage/')));
        }
        $user->delete();

        return response()->json(['message' => 'Account deleted successfully']);
    }

    public function search(Request $request)
    {
        $query = $request->query('q', '');

        if (trim($query) === '') {
            return response()->json(['users' => []]);
        }

        $users = User::query()
            ->where('id', '!=', $request->user()->id)
            ->where(function ($q) use ($query) {
                $q->where('name', 'ILIKE', "%{$query}%")
                    ->orWhere('email', 'ILIKE', "%{$query}%");
            })
            ->select('id', 'name', 'email', 'avatar_url', 'status_message')
            ->limit(20)
            ->get();

        return response()->json(['users' => $users]);
    }

}
