import os, json
import pymysql
from pathlib import Path

# DB parameters (fixed + explicit)
DB_HOST = "127.0.0.1"
DB_PORT = 3306
DB_USER = "aiops"
DB_PASS = "password"
DB_NAME = "aiops_auth"

# Connect
conn = pymysql.connect(
    host=DB_HOST,
    user=DB_USER,
    password=DB_PASS,
    database=DB_NAME,
    port=DB_PORT,
    autocommit=True
)

def upsert(cur, username, role, password_hash):
    cur.execute("""
    INSERT INTO users (username, role, password_hash)
    VALUES (%s, %s, %s)
    ON DUPLICATE KEY UPDATE
        role=VALUES(role),
        password_hash=VALUES(password_hash),
        is_active=TRUE
    """, (username, role, password_hash))

# Default users
default_users = [
    ("admin", "ADMIN", "$2b$12$uRAeNYoA6HBfATJwpI8F4u6JcwIIXELhPVuPtG1gxsfKMYyJmHWWi"),
    ("superuser", "SUPER_USER", "$2b$12$8D2hXAWEnhAUdHFTYrS8COWyYDCUfdJyIP8AdZ68UbxEcITY2mPme"),
    ("enduser", "END_USER", "$2b$12$DBXJbENe58P7Ff0Ku3.ATuGCf8nnPf/tluV8e7/1RrgUAj9EcZURi"),
]

with conn.cursor() as cur:
    for u in default_users:
        upsert(cur, *u)

# Show users
with conn.cursor() as cur:
    cur.execute("SELECT id, username, role, is_active FROM users ORDER BY id")
    rows = cur.fetchall()

print("✅ Users now in DB:")
for r in rows:
    print(r)

conn.close()
