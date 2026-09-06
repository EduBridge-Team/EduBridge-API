-- ============================================================
-- EduBridge — Database Schema (MySQL 8+)
-- نسخة MySQL من edubridge_schema.sql — تُحمّل تلقائيًا عندما
-- تربط منصة الاستضافة قاعدة بيانات MySQL بدل PostgreSQL.
-- كل الأعمدة مضمّنة داخل CREATE TABLE (بدون ALTER ADD COLUMN)
-- لأن MySQL لا يدعم ADD COLUMN IF NOT EXISTS.
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1) النواة الأساسية
-- ============================================================

-- المستخدمون
CREATE TABLE IF NOT EXISTS users (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    email               VARCHAR(150) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    role                VARCHAR(20)  NOT NULL
                        CHECK (role IN ('parent','teacher','specialist','admin','ministry','institution')),
    phone               VARCHAR(20),
    national_id         VARCHAR(30),
    id_document_url     VARCHAR(255),
    verification_status VARCHAR(20) NOT NULL DEFAULT 'pending'
                        CHECK (verification_status IN ('pending','verified','rejected')),
    verification_note   TEXT,
    verified_at         TIMESTAMP NULL DEFAULT NULL,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_users_national_id (national_id),
    INDEX idx_users_verification (verification_status)
) DEFAULT CHARSET=utf8mb4;

-- أنواع الإعاقة
CREATE TABLE IF NOT EXISTS disability_types (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(80) NOT NULL UNIQUE,
    description TEXT
) DEFAULT CHARSET=utf8mb4;

-- المؤسسات الداعمة
CREATE TABLE IF NOT EXISTS organizations (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    name    VARCHAR(150) NOT NULL,
    contact VARCHAR(150),
    address VARCHAR(255)
) DEFAULT CHARSET=utf8mb4;

-- الأطفال
CREATE TABLE IF NOT EXISTS children (
    id                       INT AUTO_INCREMENT PRIMARY KEY,
    name                     VARCHAR(100) NOT NULL,
    birth_date               DATE,
    age                      INT,
    gender                   VARCHAR(10) CHECK (gender IN ('male','female')),
    disability_type_id       INT,
    disability_type          VARCHAR(120),
    disability_description   TEXT,
    medical_history          TEXT,
    psychologist_notes       TEXT,
    special_needs            TEXT,
    preferred_learning_style VARCHAR(120),
    strengths                JSON,
    challenges               JSON,
    status                   VARCHAR(20) NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','evaluated','assigned')),
    assigned_teacher_id      INT,
    organization_id          INT,
    notes                    TEXT,
    child_national_id        VARCHAR(30),
    guardian_national_id     VARCHAR(30),
    guardian_id_document_url VARCHAR(255),
    kinship_document_url     VARCHAR(255),
    doc_verification_status  VARCHAR(20) NOT NULL DEFAULT 'pending'
                             CHECK (doc_verification_status IN ('pending','verified','rejected')),
    doc_verification_note    TEXT,
    created_at               TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_children_disability (disability_type_id),
    INDEX idx_children_assigned_teacher (assigned_teacher_id),
    INDEX idx_children_child_national (child_national_id),
    CONSTRAINT fk_children_disability FOREIGN KEY (disability_type_id) REFERENCES disability_types(id) ON DELETE RESTRICT,
    CONSTRAINT fk_children_teacher    FOREIGN KEY (assigned_teacher_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_children_org        FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL
) DEFAULT CHARSET=utf8mb4;

-- التقييمات
CREATE TABLE IF NOT EXISTS evaluations (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    child_id             INT NOT NULL,
    evaluator_id         INT,
    evaluation_type      VARCHAR(60),
    cognitive_assessment TEXT,
    motor_assessment     TEXT,
    emotional_assessment TEXT,
    social_assessment    TEXT,
    recommendations      TEXT,
    educational_plan     TEXT,
    teaching_methods     JSON,
    assigned_teacher_id  INT,
    created_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_evaluations_child (child_id),
    CONSTRAINT fk_eval_child     FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    CONSTRAINT fk_eval_evaluator FOREIGN KEY (evaluator_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_eval_teacher   FOREIGN KEY (assigned_teacher_id) REFERENCES users(id) ON DELETE SET NULL
) DEFAULT CHARSET=utf8mb4;

-- ربط الطفل بأولياء أمره (many-to-many)
CREATE TABLE IF NOT EXISTS child_parent (
    child_id  INT NOT NULL,
    parent_id INT NOT NULL,
    PRIMARY KEY (child_id, parent_id),
    CONSTRAINT fk_cp_child  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    CONSTRAINT fk_cp_parent FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- الدروس
CREATE TABLE IF NOT EXISTS lessons (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    title              VARCHAR(150) NOT NULL,
    content            TEXT,
    disability_type_id INT,
    teacher_id         INT,
    education_level    VARCHAR(60),
    curriculum_status  VARCHAR(20) NOT NULL DEFAULT 'pending'
                       CHECK (curriculum_status IN ('pending','approved','rejected')),
    reviewed_by        INT,
    review_note        TEXT,
    reviewed_at        TIMESTAMP NULL DEFAULT NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lessons_disability (disability_type_id),
    INDEX idx_lessons_curriculum (curriculum_status),
    CONSTRAINT fk_lessons_disability FOREIGN KEY (disability_type_id) REFERENCES disability_types(id) ON DELETE SET NULL,
    CONSTRAINT fk_lessons_teacher    FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_lessons_reviewer   FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) DEFAULT CHARSET=utf8mb4;

-- تقدّم الطفل بكل درس
CREATE TABLE IF NOT EXISTS progress (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    child_id     INT NOT NULL,
    lesson_id    INT NOT NULL,
    status       VARCHAR(15) NOT NULL DEFAULT 'not_started'
                 CHECK (status IN ('not_started','in_progress','done')),
    score        INT CHECK (score BETWEEN 0 AND 100),
    completed_at TIMESTAMP NULL DEFAULT NULL,
    UNIQUE KEY uq_progress_child_lesson (child_id, lesson_id),
    INDEX idx_progress_child (child_id),
    CONSTRAINT fk_progress_child  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    CONSTRAINT fk_progress_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 2) الإضافات
-- ============================================================

-- الوسائط المرتبطة بالدروس
CREATE TABLE IF NOT EXISTS media (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id INT NOT NULL,
    type      VARCHAR(10) NOT NULL CHECK (type IN ('image','video','audio')),
    url       VARCHAR(255) NOT NULL,
    CONSTRAINT fk_media_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- جلسات المختص مع الطفل
CREATE TABLE IF NOT EXISTS sessions (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    specialist_id INT NOT NULL,
    child_id      INT NOT NULL,
    scheduled_at  TIMESTAMP NOT NULL,
    status        VARCHAR(15) NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','done','cancelled')),
    INDEX idx_sessions_child (child_id),
    CONSTRAINT fk_sessions_specialist FOREIGN KEY (specialist_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_sessions_child      FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- ملاحظات المعلّم / المختص عن الطفل
CREATE TABLE IF NOT EXISTS notes (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    author_id  INT NOT NULL,
    child_id   INT NOT NULL,
    content    TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notes_child (child_id),
    CONSTRAINT fk_notes_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_notes_child  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- الإشعارات
CREATE TABLE IF NOT EXISTS notifications (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    title      VARCHAR(150),
    message    VARCHAR(255) NOT NULL,
    type       VARCHAR(40),
    is_read    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notifications_user (user_id),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 3) بطاقات اللوحة
-- ============================================================

-- شهادات المعلّم/المختص
CREATE TABLE IF NOT EXISTS certificates (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    title      VARCHAR(150) NOT NULL,
    url        VARCHAR(255) NOT NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','verified','rejected')),
    note       TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_certificates_user (user_id),
    CONSTRAINT fk_certificates_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- تقييمات المادة التعليمية
CREATE TABLE IF NOT EXISTS lesson_ratings (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    lesson_id  INT NOT NULL,
    user_id    INT NOT NULL,
    stars      INT NOT NULL CHECK (stars BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_lesson_ratings (lesson_id, user_id),
    INDEX idx_lesson_ratings_lesson (lesson_id),
    CONSTRAINT fk_ratings_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    CONSTRAINT fk_ratings_user   FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- الدعم الفني والشكاوى
CREATE TABLE IF NOT EXISTS support_tickets (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    category    VARCHAR(20) NOT NULL DEFAULT 'support'
                CHECK (category IN ('support','complaint')),
    subject     VARCHAR(150) NOT NULL,
    message     TEXT NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','in_progress','resolved','closed')),
    admin_reply TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_support_tickets_user (user_id),
    INDEX idx_support_tickets_status (status),
    CONSTRAINT fk_support_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- دراسة الحالة مع المختصين
CREATE TABLE IF NOT EXISTS consultations (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    child_id      INT NOT NULL,
    requester_id  INT NOT NULL,
    specialist_id INT,
    title         VARCHAR(150) NOT NULL,
    description   TEXT,
    status        VARCHAR(20) NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','assigned','in_progress','closed')),
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_consultations_child (child_id),
    INDEX idx_consultations_specialist (specialist_id),
    CONSTRAINT fk_consult_child      FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    CONSTRAINT fk_consult_requester  FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_consult_specialist FOREIGN KEY (specialist_id) REFERENCES users(id) ON DELETE SET NULL
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS consultation_notes (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT NOT NULL,
    author_id       INT NOT NULL,
    content         TEXT NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_consultation_notes_consultation (consultation_id),
    CONSTRAINT fk_cnotes_consultation FOREIGN KEY (consultation_id) REFERENCES consultations(id) ON DELETE CASCADE,
    CONSTRAINT fk_cnotes_author       FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
