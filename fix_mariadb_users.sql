USE aiops_auth;

-- 1. Ensure the table can support the UPPERCASE roles
ALTER TABLE users MODIFY COLUMN role ENUM('SUPER_ADMIN', 'ADMIN', 'SUPER_USER', 'END_USER', 'user', 'admin') NOT NULL;

-- 2. Insert/Update all users with the Password Hash that works for Lesiba
-- We copy Lesiba's hash if it exists, otherwise we set the known hash for 'password'
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
SELECT username, role FROM users;
