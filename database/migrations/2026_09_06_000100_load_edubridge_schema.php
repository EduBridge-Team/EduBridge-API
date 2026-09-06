<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Builds the EduBridge domain schema from the canonical SQL dump
 * (edubridge_schema.sql) rather than hand-written Laravel migrations.
 *
 * The dump is idempotent (every CREATE TABLE/INDEX uses IF NOT EXISTS and the
 * ALTERs use ADD COLUMN IF NOT EXISTS), so this migration is safe to re-run.
 * Demo data from edubridge_seed.sql is loaded only when the database is empty.
 */
return new class extends Migration
{
    public function up(): void
    {
        // One-time reconciliation: this app's authoritative `users` table and its
        // domain `sessions` table live in edubridge_schema.sql, not in Laravel's
        // default auth migration. If an earlier deploy created Laravel's default
        // tables, drop them so the canonical schema below builds the correct
        // structures. On a fresh database these are harmless no-ops.
        DB::unprepared('DROP TABLE IF EXISTS sessions, password_reset_tokens, users CASCADE;');

        DB::unprepared(file_get_contents(base_path('edubridge_schema.sql')));

        if (DB::table('users')->count() === 0) {
            DB::unprepared(file_get_contents(base_path('edubridge_seed.sql')));
        }
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS
            consultation_notes, consultations, support_tickets, lesson_ratings,
            certificates, notifications, notes, sessions, media, progress,
            lessons, child_parent, evaluations, children, organizations,
            disability_types, users CASCADE;');
    }
};
