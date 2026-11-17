"""Autenticación: bcrypt para contraseñas, JWT para sesiones y control por rol.

- get_usuario_actual: lee el header "Authorization: Bearer <token>" y lo valida.
- require_role("admin", ...): dependencia que deja pasar solo a esos roles.
- get_conn: conexión del pool con app.usuario_id fijado (para la auditoría).
"""
import os
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .db import usar_conexion

JWT_SECRET = os.environ["JWT_SECRET"]
JWT_EXPIRE_MINUTES = int(os.environ.get("JWT_EXPIRE_MINUTES", "480"))
JWT_ALGORITMO = "HS256"

# auto_error=False: así el mensaje de "falta el token" sale en español
esquema_bearer = HTTPBearer(auto_error=False)


# ---------------------------------------------------------------- contraseñas
def hashear_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(12)).decode("utf-8")


def verificar_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


# ---------------------------------------------------------------- tokens
def crear_token(usuario: dict) -> str:
    ahora = datetime.now(timezone.utc)
    payload = {
        "sub": str(usuario["id"]),
        "nombre": usuario["nombre"],
        "rol": usuario["rol"],
        "iat": ahora,
        "exp": ahora + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITMO)


def get_usuario_actual(
    credenciales: HTTPAuthorizationCredentials | None = Depends(esquema_bearer),
) -> dict:
    no_autorizado = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Sesión no válida o vencida. Inicie sesión de nuevo.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credenciales is None:
        raise no_autorizado
    try:
        payload = jwt.decode(credenciales.credentials, JWT_SECRET, algorithms=[JWT_ALGORITMO])
    except jwt.PyJWTError:
        raise no_autorizado
    return {"id": int(payload["sub"]), "nombre": payload["nombre"], "rol": payload["rol"]}


def require_role(*roles: str):
    """Uso: usuario = Depends(require_role("admin")). Responde 403 si el rol no está."""

    def verificar(usuario: dict = Depends(get_usuario_actual)) -> dict:
        if usuario["rol"] not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tiene permisos para realizar esta acción",
            )
        return usuario

    return verificar


# ---------------------------------------------------------------- conexiones
def get_conn(usuario: dict = Depends(get_usuario_actual)):
    """Conexión para rutas protegidas: la auditoría registra a este usuario."""
    yield from usar_conexion(usuario["id"])


def get_conn_publica():
    """Conexión para rutas sin sesión (login): app.usuario_id queda vacío."""
    yield from usar_conexion(None)
