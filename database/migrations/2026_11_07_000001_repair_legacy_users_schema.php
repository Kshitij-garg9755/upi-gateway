<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Some distributed SQLite databases record the original users migration as
     * complete while still having the older, smaller users table. Add only the
     * columns required by the current application and preserve existing rows.
     */
    public function up(): void
    {
        $missing = [];

        foreach ([
            'role',
            'business_name',
            'phone',
            'is_active',
            'api_key',
            'api_secret',
            'webhook_url',
        ] as $column) {
            if (! Schema::hasColumn('users', $column)) {
                $missing[] = $column;
            }
        }

        if ($missing === []) {
            return;
        }

        Schema::table('users', function (Blueprint $table) use ($missing): void {
            foreach ($missing as $column) {
                match ($column) {
                    'role' => $table->string('role')->default('merchant'),
                    'business_name' => $table->string('business_name')->nullable(),
                    'phone' => $table->string('phone', 20)->nullable(),
                    'is_active' => $table->boolean('is_active')->default(true),
                    'api_key' => $table->string('api_key')->nullable(),
                    'api_secret' => $table->text('api_secret')->nullable(),
                    'webhook_url' => $table->string('webhook_url')->nullable(),
                };
            }

            if (in_array('api_key', $missing, true)) {
                $table->unique('api_key');
            }
        });
    }

    /**
     * Keep the compatibility columns on rollback so existing account data is
     * not lost if a user created accounts after this migration ran.
     */
    public function down(): void
    {
        // Intentionally left in place to avoid deleting merchant credentials.
    }
};
