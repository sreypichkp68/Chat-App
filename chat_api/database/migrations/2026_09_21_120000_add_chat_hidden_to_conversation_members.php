<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversation_members', function (Blueprint $table) {
            $table->boolean('chat_hidden')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('conversation_members', function (Blueprint $table) {
            $table->dropColumn('chat_hidden');
        });
    }
};
