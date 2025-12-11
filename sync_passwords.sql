USE aiops_auth;

-- Update tumi, koki, ramo, and lesiba to have the SAME password hash as 'admin'
UPDATE users 
SET password_hash = (
    SELECT password_hash FROM (
        SELECT password_hash FROM users WHERE username = 'admin' LIMIT 1
    ) as source_hash
)
WHERE username IN ('tumi', 'koki', 'ramo', 'lesiba');

-- Verify the hashes are now identical
SELECT username, role, LEFT(password_hash, 10) as hash_prefix FROM users;
