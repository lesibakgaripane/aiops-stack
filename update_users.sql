USE aiops_auth;

-- Insert/Update Users with password 'password'
-- The hash below corresponds to 'password'
INSERT INTO users (username, hashed_password, role, is_active) VALUES 
('lesiba', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'superadmin', 1),
('tumi',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'admin',      1),
('koki',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'superuser',  1),
('ramo',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj40.D.y.N.e', 'user',       1)
ON DUPLICATE KEY UPDATE 
    role = VALUES(role), 
    hashed_password = VALUES(hashed_password), 
    is_active = 1;

-- Verify the results
SELECT username, role, is_active FROM users;
