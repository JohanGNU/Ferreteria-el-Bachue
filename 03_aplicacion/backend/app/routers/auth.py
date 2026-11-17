"""Login y datos de la sesión actual."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from ..auth import crear_token, get_conn_publica, get_usuario_actual, verificar_password

router = APIRouter(prefix="/api/auth", tags=["auth"])


class LoginEntrada(BaseModel):
    email: str = Field(min_length=3, max_length=120)
    password: str = Field(min_length=1, max_length=72)  # bcrypt usa máximo 72 bytes


@router.post("/login")
def login(datos: LoginEntrada, conn=Depends(get_conn_publica)):
    usuario = conn.execute(
        """
        SELECT u.id, u.nombre, u.password_hash, r.nombre AS rol
        FROM usuarios u
        JOIN roles r ON r.id = u.rol_id
        WHERE u.email = lower(%s) AND u.activo
        """,
        (datos.email.strip(),),
    ).fetchone()

    # Mismo mensaje si no existe el correo o si la clave falla: no revela cuál
    if usuario is None or not verificar_password(datos.password, usuario["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos",
        )

    datos_usuario = {"id": usuario["id"], "nombre": usuario["nombre"], "rol": usuario["rol"]}
    return {"access_token": crear_token(datos_usuario), "usuario": datos_usuario}


@router.get("/yo")
def usuario_actual(usuario: dict = Depends(get_usuario_actual)):
    """Devuelve el usuario del token (el frontend lo usa al recargar la página)."""
    return usuario
