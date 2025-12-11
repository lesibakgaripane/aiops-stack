USE aiops_auth;

-- 1. Relax the column to VARCHAR so we can clean data without errors
ALTER TABLE users MODIFY COLUMN role VARCHAR(64) NOT NULL;

-- 2. Standardize all roles to UPPERCASE
-- This ensures 'admin' becomes 'ADMIN', 'user' becomes 'END_USER', etc.
UPDATE users SET role = 'SUPER_ADMIN' WHERE username = 'lesiba';
UPDATE users SET role = 'ADMIN'       WHERE username = 'tumi';
UPDATE users SET role = 'SUPER_USER'  WHERE username = 'koki';
UPDATE users SET role = 'END_USER'    WHERE username = 'ramo';

-- 3. Cleanup any leftovers (e.g. old 'admin' account)
UPDATE users SET role = 'ADMIN'    WHERE role = 'admin';
UPDATE users SET role = 'END_USER' WHERE role = 'user';

-- 4. Sync Passwords: Copy Lesiba's working hash to everyone else
UPDATE users 
SET password_hash = (
    SELECT password_hash FROM (
        SELECT password_hash FROM users WHERE username = 'lesiba' LIMIT 1
    ) as source
)
WHERE username IN ('tumi', 'koki', 'ramo', 'admin');

-- 5. Force all accounts active
UPDATE users SET is_active = 1;

-- 6. NOW re-apply the Strict ENUM (Clean Uppercase only)
ALTER TABLE users MODIFY COLUMN role ENUM('SUPER_ADMIN', 'ADMIN', 'SUPER_USER', 'END_USER') NOT NULL;

-- 7. Verify Results
SELECT username, role, is_active FROM users;
