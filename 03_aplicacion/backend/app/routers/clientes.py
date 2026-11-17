"""CRUD de clientes (admin y vendedor).

El listado trae la clasificación de fn_clasificar_cliente (Premium, Frecuente
o Básico). Eliminar va por sp_eliminar_cliente: si el cliente tiene ventas se
desactiva; si no, se borra.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import EmailStr, Field

from ..auth import get_conn, require_role
from ..db import patron_busqueda
from ..esquemas import Entrada

router = APIRouter(prefix="/api/clientes", tags=["clientes"])

SQL_CLIENTES = """
    SELECT c.id, c.documento, c.nombre, c.telefono, c.email, c.activo,
           fn_clasificar_cliente(c.id) AS clasificacion
    FROM clientes c
"""


class ClienteEntrada(Entrada):
    documento: str = Field(min_length=5, max_length=20, pattern=r"^[0-9-]+$")
    nombre: str = Field(min_length=2, max_length=120)
    telefono: str | None = Field(default=None, max_length=20, pattern=r"^[0-9 +()-]+$")
    email: EmailStr | None = None
    activo: bool = True


def obtener_cliente(conn, cliente_id: int) -> dict:
    cliente = conn.execute(SQL_CLIENTES + " WHERE c.id = %s", (cliente_id,)).fetchone()
    if cliente is None:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return cliente


@router.get("")
def listar_clientes(
    q: str | None = None,
    solo_activos: bool = False,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    return conn.execute(
        SQL_CLIENTES
        + """
        WHERE (%(patron)s::text IS NULL OR c.nombre ILIKE %(patron)s OR c.documento ILIKE %(patron)s)
          AND (NOT %(solo_activos)s OR c.activo)
        ORDER BY c.nombre
        """,
        {"patron": patron_busqueda(q), "solo_activos": solo_activos},
    ).fetchall()


@router.get("/{cliente_id}")
def ver_cliente(
    cliente_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    return obtener_cliente(conn, cliente_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_cliente(
    datos: ClienteEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    fila = conn.execute(
        """
        INSERT INTO clientes (documento, nombre, telefono, email, activo)
        VALUES (%s, %s, %s, lower(%s), %s)
        RETURNING id
        """,
        (datos.documento, datos.nombre, datos.telefono, datos.email, datos.activo),
    ).fetchone()
    return obtener_cliente(conn, fila["id"])


@router.put("/{cliente_id}")
def actualizar_cliente(
    cliente_id: int,
    datos: ClienteEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    cur = conn.execute(
        """
        UPDATE clientes
           SET documento = %s, nombre = %s, telefono = %s, email = lower(%s), activo = %s
         WHERE id = %s
        """,
        (datos.documento, datos.nombre, datos.telefono, datos.email, datos.activo, cliente_id),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return obtener_cliente(conn, cliente_id)


@router.delete("/{cliente_id}")
def eliminar_cliente(
    cliente_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    fila = conn.execute("CALL sp_eliminar_cliente(%s, NULL)", (cliente_id,)).fetchone()
    if fila["p_resultado"] == "DESACTIVADO":
        return {"resultado": "DESACTIVADO",
                "detail": "El cliente tiene ventas registradas: se desactivó en lugar de eliminarse"}
    return {"resultado": "ELIMINADO", "detail": "Cliente eliminado"}
