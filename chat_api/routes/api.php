<?php
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\CallController;
use App\Http\Controllers\Api\GroupController;
use App\Http\Controllers\ConversationController;
use App\Http\Controllers\FriendRequestController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

// Public routes
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login'])->name('login');

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
 // Broadcasting Auth
    Route::post('/broadcasting/auth', function (Request $request) {

        Log::warning('API BROADCAST AUTH', [
            'user_id' => $request->user()?->id,
            'channel_name' => $request->input('channel_name'),
            'socket_id' => $request->input('socket_id'),
        ]);

        return Broadcast::auth($request);
    });
    // call
    Route::post('/calls/invite', [CallController::class, 'invite']);
    Route::post('/calls/accept', [CallController::class, 'accept']);
    Route::post('/calls/decline', [CallController::class, 'decline']);
    Route::post('/calls/{callId}/end', [CallController::class, 'end']);
    Route::get('/calls/token', [CallController::class, 'token']);
    // Image
    Route::post('/messages/upload', [MessageController::class, 'uploadImage']);
    // Authentication
    Route::post('/logout', [AuthController::class, 'logout']);
    // search user
    Route::get('/users/search', [UserController::class, 'search']);
    // request friend
    Route::delete('/friends/{friendId}', [FriendRequestController::class, 'destroyFriend']);
    Route::get('/friends', [FriendRequestController::class, 'friends']);
    Route::post('/friend-requests', [FriendRequestController::class, 'store']);
    Route::get('/friend-requests', [FriendRequestController::class, 'index']);
    Route::put('/friend-requests/{friendRequest}', [FriendRequestController::class, 'update']);
    // User profile
    Route::get('/user/profile', [UserController::class, 'show']);
    Route::put('/user/profile', [UserController::class, 'update']);
    Route::delete('/user/profile', [UserController::class, 'destroy']);
    // Conversations
    Route::get('/conversations', [ConversationController::class, 'index']);
    Route::post('/conversations', [ConversationController::class, 'store']);
    // Messages
    Route::get('/conversations/{conversation}/messages', [MessageController::class, 'index']);
    Route::post('/conversations/{conversation}/messages', [MessageController::class, 'store']);
    Route::put('/messages/{message}', [MessageController::class, 'update']);
    Route::delete('/messages/{message}', [MessageController::class, 'destroy']);
    // Groups
    Route::post('/groups', [GroupController::class, 'store']);
    Route::post('/groups/{group}/members', [GroupController::class, 'addMember']);
    Route::delete('/groups/{group}/members/{userId}', [GroupController::class, 'removeMember']);
});
