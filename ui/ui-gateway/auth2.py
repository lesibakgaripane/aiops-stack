import os
from datetime import datetime, timedelta
from typing import Optional

import bcrypt
import pymysql
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel

router = APIRouter()

# ---- DB settings ----
AUTH_DB_HOST = os.getenv("AUTH_DB_HOST", "127.0.0.1")
AUTH_DB_PORT = int(os.getenv("AUTH_DB_PORT", "3307"))
AUTH_DB_USER = os.getenv("AUTH_DB_USER", "aiops")
AUTH_DB_PASS = os.getenv("AUTH_DB_PASS", "password")
AUTH_DB_NAME = os.getenv("AUTH_DB_NAME", "aiops_auth")

# ---- JWT settings ----
SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "aiops-ui-dev-secret")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth2/login")


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    username: Optional[str] = None


class User(BaseModel):
    id: int
    username: str
    role: str
    is_active: bool


class UserInDB(User):
    password_hash: str


def get_db_conn():
    return pymysql.connect(
        host=AUTH_DB_HOST,
        port=AUTH_DB_PORT,
        user=AUTH_DB_USER,
        password=AUTH_DB_PASS,
        database=AUTH_DB_NAME,
        autocommit=True,
    )


def verify_password(plain_password: str, password_hash: str) -> bool:
    """
    Compare plain text password with bcrypt hash from DB.
    DB hashes are passlib-generated `$2b$...`, bcrypt.checkpw can verify them.
    """
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            password_hash.encode("utf-8"),
        )
    except Exception as e:
        # Log to stdout; won't be sent to client
        print("auth2 bcrypt verify error:", e)
        return False


def get_user(username: str) -> Optional[UserInDB]:
    conn = get_db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, username, role, password_hash, is_active "
                "FROM users WHERE username=%s",
                (username,),
            )
            row = cur.fetchone()
    finally:
        conn.close()

    if not row:
        return None

    uid, uname, role, phash, active = row
    return UserInDB(
        id=uid,
        username=uname,
        role=role,
        password_hash=phash,
        is_active=bool(active),
    )


def authenticate_user(username: str, password: str) -> Optional[UserInDB]:
    user = get_user(username)
    if not user:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(token: str = Depends(oauth2_scheme)) -> UserInDB:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials (auth2)",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: Optional[str] = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = get_user(username)
    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(
    current_user: UserInDB = Depends(get_current_user),
) -> UserInDB:
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user (auth2)",
        )
    return current_user


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Form-encoded login:
      username=admin&password=password
    Returns JWT access_token if OK.
    """
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password (auth2)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me")
async def read_users_me(current_user: UserInDB = Depends(get_current_active_user)):
    """
    Return basic info about current user.
    """
    return {
        "id": current_user.id,
        "username": current_user.username,
        "role": current_user.role,
        "is_active": current_user.is_active,
    }
