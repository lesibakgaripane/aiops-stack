import pymysql
from passlib.context import CryptContext

# --- DB connection (dedicated auth DB on port 3307) ---
DB_HOST = "127.0.0.1"
DB_PORT = 3307
DB_USER = "aiops"
DB_PASS = "password"
DB_NAME = "aiops_auth"

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_conn():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        autocommit=True,
    )

def upsert_user(cur, username, role, password_plain):
    password_hash = pwd.hash(password_plain)
    cur.execute(
        """
        INSERT INTO users (username, role, password_hash, is_active)
        VALUES (%s, %s, %s, TRUE)
        ON DUPLICATE KEY UPDATE
          role = VALUES(role),
          password_hash = VALUES(password_hash),
          is_active = TRUE
        """,
        (username, role, password_hash),
    )

def main():
    conn = get_conn()
    cur = conn.cursor()

    # Default users (password = "password" for all)
    defaults = [
        ("admin",     "ADMIN",      "password"),
        ("superuser", "SUPER_USER", "password"),
        ("enduser",   "END_USER",   "password"),
    ]

    for u, r, p in defaults:
        upsert_user(cur, u, r, p)

    cur.execute("SELECT username, role, is_active FROM users ORDER BY id;")
    rows = cur.fetchall()
    print("✅ Users now in aiops_auth.users:")
    for row in rows:
        print(row)

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
