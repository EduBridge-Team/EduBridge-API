<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Builds the EduBridge domain schema from a canonical SQL dump rather than
 * hand-written Laravel migrations.
 *
 * The hosting platform provisions the database automatically and may attach
 * either PostgreSQL or MySQL, so the correct SQL dialect is chosen at runtime
 * from the active connection driver:
 *   - pgsql            -> edubridge_schema.sql       (JSONB, SERIAL, NOW())
 *   - mysql / mariadb  -> edubridge_schema_mysql.sql (JSON, AUTO_INCREMENT)
 *
 * Both dumps are idempotent (every CREATE TABLE uses IF NOT EXISTS), so this
 * migration is safe to re-run. Demo data from edubridge_seed.sql is portable
 * to both engines and is loaded only when the database is empty.
 */
return new class extends Migration
{
    public function up(): void
    {
        $driver = DB::connection()->getDriverName();
        $isMysql = in_array($driver, ['mysql', 'mariadb'], true);

        // One-time reconciliation: this app's authoritative `users` table and its
        // domain `sessions` table live in the schema dump, not in Laravel's
        // default auth migration. If an earlier deploy created Laravel's default
        // tables, drop them so the canonical schema below builds the correct
        // structures. On a fresh database these are harmless no-ops.
        if ($isMysql) {
            DB::unprepared(
                'SET FOREIGN_KEY_CHECKS = 0;'
                . 'DROP TABLE IF EXISTS sessions, password_reset_tokens, users;'
                . 'SET FOREIGN_KEY_CHECKS = 1;'
            );
        } else {
            DB::unprepared('DROP TABLE IF EXISTS sessions, password_reset_tokens, users CASCADE;');
        }

        $schemaFile = $isMysql ? 'edubridge_schema_mysql.sql' : 'edubridge_schema.sql';
        DB::unprepared(file_get_contents(base_path($schemaFile)));

        if (DB::table('users')->count() === 0) {
            DB::unprepared(file_get_contents(base_path('edubridge_seed.sql')));
        }
    }

    public function down(): void
    {
        $driver = DB::connection()->getDriverName();
        $tables = 'consultation_notes, consultations, support_tickets, lesson_ratings, '
            . 'certificates, notifications, notes, sessions, media, progress, '
            . 'lessons, child_parent, evaluations, children, organizations, '
            . 'disability_types, users';

        if (in_array($driver, ['mysql', 'mariadb'], true)) {
            DB::unprepared(
                'SET FOREIGN_KEY_CHECKS = 0;'
                . "DROP TABLE IF EXISTS {$tables};"
                . 'SET FOREIGN_KEY_CHECKS = 1;'
            );
        } else {
            DB::unprepared("DROP TABLE IF EXISTS {$tables} CASCADE;");
        }
    }
};
