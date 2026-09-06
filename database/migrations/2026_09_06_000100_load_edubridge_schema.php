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
