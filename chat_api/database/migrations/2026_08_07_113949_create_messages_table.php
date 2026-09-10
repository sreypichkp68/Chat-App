<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 3. MESSAGES TABLE
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();
            
            $table->text('content')->nullable(); // Text message content
            
            // Types: 'text', 'image', 'audio', 'file', 'call_log', 'system'
            $table->string('message_type', 20)->default('text'); 
            
            // JSON: media URLs, voice note duration, call logs, and emoji reactions
            $table->json('metadata')->nullable(); 

            $table->foreignId('reply_to_message_id')->nullable()->constrained('messages')->nullOnDelete();
            $table->timestamps();

            // Index for fast query loading
            $table->index(['conversation_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('messages');
    }
};
