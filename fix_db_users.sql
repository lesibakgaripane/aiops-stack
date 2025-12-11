USE aiops_auth;

-- 1. Modify the table to allow 'SUPER_ADMIN' and ensure all roles are available
ALTER TABLE users MODIFY COLUMN role ENUM('SUPER_ADMIN', 'ADMIN', 'SUPER_USER', 'END_USER') NOT NULL;

-- 2. Insert/Update Users using the correct column 'password_hash' and UPPERCASE roles
INSERT INTO users (username, password_hash, role, is_active) VALUES 
('lesiba', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'SUPER_ADMIN', 1),
('tumi',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'ADMIN',       1),
('koki',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'SUPER_USER',  1),
('ramo',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'END_USER',    1)
ON DUPLICATE KEY UPDATE 
    role = VALUES(role), 
    password_hash = VALUES(password_hash), 
    is_active = 1;

-- 3. Verify
SELECT username, role, is_active FROM users;
