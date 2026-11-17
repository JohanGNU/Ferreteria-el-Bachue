"""CRUD de usuarios (solo admin).

La contraseña se guarda con bcrypt (hashear_password); nunca se devuelve el hash.
Un admin no puede eliminarse, desactivarse ni quitarse el rol a sí mismo,
para no quedar el sistema sin acceso.
"""
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import EmailStr, Field

from ..auth import get_conn, hashear_password, require_role
from ..db import patron_busqueda
from ..esquemas import Entrada

router = APIRouter(prefix="/api/usuarios", tags=["usuarios"])

SQL_USUARIOS = """
    SELECT u.id, u.nombre, u.email, r.nombre AS rol, u.activo
    FROM usuarios u
    JOIN roles r ON r.id = u.rol_id
"""


class UsuarioBase(Entrada):
    nombre: str = Field(min_length=2, max_length=100)
    email: EmailStr
    rol: Literal["admin", "vendedor"]
    activo: bool = True


class UsuarioCrear(UsuarioBase):
    password: str = Field(min_length=8, max_length=72)


class UsuarioActualizar(UsuarioBase):
    password: str | None = Field(default=None, min_length=8, max_length=72)  # vacío = no cambia


def obtener_usuario(conn, usuario_id: int) -> dict:
    usuario = conn.execute(SQL_USUARIOS + " WHERE u.id = %s", (usuario_id,)).fetchone()
    if usuario is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@router.get("")
def listar_usuarios(
    q: str | None = None,
    conn=Depends(get_conn),
    actual: dict = Depends(require_role("admin")),
):
    return conn.execute(
        SQL_USUARIOS
        + """
        WHERE (%(patron)s::text IS NULL OR u.nombre ILIKE %(patron)s OR u.email ILIKE %(patron)s)
        ORDER BY u.nombre
        """,
        {"patron": patron_busqueda(q)},
    ).fetchall()


@router.get("/{usuario_id}")
def ver_usuario(
    usuario_id: int,
    conn=Depends(get_conn),
    actual: dict = Depends(require_role("admin")),
):
    return obtener_usuario(conn, usuario_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_usuario(
    datos: UsuarioCrear,
    conn=Depends(get_conn),
    actual: dict = Depends(require_role("admin")),
):
    fila = conn.execute(
        """
        INSERT INTO usuarios (nombre, email, password_hash, rol_id, activo)
        VALUES (%s, lower(%s), %s, (SELECT id FROM roles WHERE nombre = %s), %s)
        RETURNING id
        """,
        (datos.nombre, datos.email, hashear_password(datos.password), datos.rol, datos.activo),
    ).fetchone()
    return obtener_usuario(conn, fila["id"])


@router.put("/{usuario_id}")
def actualizar_usuario(
    usuario_id: int,
    datos: UsuarioActualizar,
    conn=Depends(get_conn),
    actual: dict = Depends(require_role("admin")),
):
    if usuario_id == actual["id"] and (not datos.activo or datos.rol != "admin"):
        raise HTTPException(status_code=400,
                            detail="No puede desactivarse ni quitarse el rol de administrador a sí mismo")

    nuevo_hash = hashear_password(datos.password) if datos.password else None
    cur = conn.execute(
        """
        UPDATE usuarios
           SET nombre = %s,
               email = lower(%s),
               rol_id = (SELECT id FROM roles WHERE nombre = %s),
               activo = %s,
               password_hash = COALESCE(%s, password_hash)
         WHERE id = %s
        """,
        (datos.nombre, datos.email, datos.rol, datos.activo, nuevo_hash, usuario_id),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return obtener_usuario(conn, usuario_id)


@router.delete("/{usuario_id}")
def eliminar_usuario(
    usuario_id: int,
    conn=Depends(get_conn),
    actual: dict = Depends(require_role("admin")),
):
    """Si el usuario ya registró ventas o movimientos, la FK lo impide (409): se desactiva."""
    if usuario_id == actual["id"]:
        raise HTTPException(status_code=400, detail="No puede eliminar su propio usuario")
    cur = conn.execute("DELETE FROM usuarios WHERE id = %s", (usuario_id,))
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"detail": "Usuario eliminado"}
