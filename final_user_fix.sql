USE aiops_auth;

-- 1. Overwrite EVERYONE'S password with the hash from 'lesiba' (since we know it works)
UPDATE users 
SET password_hash = (
    SELECT password_hash FROM (
        SELECT password_hash FROM users WHERE username = 'lesiba' LIMIT 1
    ) as source
)
WHERE username IN ('tumi', 'koki', 'ramo', 'admin');

-- 2. Force all accounts to be active
UPDATE users SET is_active = 1;

-- 3. Verify the data one last time
SELECT username, role, is_active, LEFT(password_hash, 10) as hash_check FROM users;
