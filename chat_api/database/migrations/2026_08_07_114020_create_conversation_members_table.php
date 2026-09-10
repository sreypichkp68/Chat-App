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
        // 4. CONVERSATION MEMBERS TABLE
        Schema::create('conversation_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('role', ['admin', 'member'])->default('member');
            
            // Foreign key referencing messages
            $table->foreignId('last_read_message_id')->nullable()->constrained('messages')->nullOnDelete();
            
            $table->timestamp('joined_at')->useCurrent();
            $table->timestamps();

            $table->unique(['conversation_id', 'user_id']); // Prevents duplicate members
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('conversation_members');
    }
};
