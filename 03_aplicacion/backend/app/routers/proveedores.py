"""CRUD de proveedores (solo admin). SQL directo con parámetros.

La entrada de mercancía de los productos de un proveedor está en
POST /api/productos/{id}/entradas (sp_registrar_entrada).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import EmailStr, Field

from ..auth import get_conn, require_role
from ..db import patron_busqueda
from ..esquemas import Entrada

router = APIRouter(prefix="/api/proveedores", tags=["proveedores"])

SQL_PROVEEDORES = """
    SELECT pr.id, pr.nit, pr.nombre, pr.telefono, pr.email, pr.activo,
           count(p.id) AS total_productos
    FROM proveedores pr
    LEFT JOIN productos p ON p.proveedor_id = pr.id
"""


class ProveedorEntrada(Entrada):
    nit: str = Field(min_length=5, max_length=20, pattern=r"^[0-9-]+$")
    nombre: str = Field(min_length=2, max_length=120)
    telefono: str | None = Field(default=None, max_length=20, pattern=r"^[0-9 +()-]+$")
    email: EmailStr | None = None
    activo: bool = True


def obtener_proveedor(conn, proveedor_id: int) -> dict:
    proveedor = conn.execute(
        SQL_PROVEEDORES + " WHERE pr.id = %s GROUP BY pr.id", (proveedor_id,)
    ).fetchone()
    if proveedor is None:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    return proveedor


@router.get("")
def listar_proveedores(
    q: str | None = None,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    return conn.execute(
        SQL_PROVEEDORES
        + """
        WHERE (%(patron)s::text IS NULL OR pr.nombre ILIKE %(patron)s OR pr.nit ILIKE %(patron)s)
        GROUP BY pr.id
        ORDER BY pr.nombre
        """,
        {"patron": patron_busqueda(q)},
    ).fetchall()


@router.get("/{proveedor_id}")
def ver_proveedor(
    proveedor_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    return obtener_proveedor(conn, proveedor_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_proveedor(
    datos: ProveedorEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    fila = conn.execute(
        """
        INSERT INTO proveedores (nit, nombre, telefono, email, activo)
        VALUES (%s, %s, %s, lower(%s), %s)
        RETURNING id
        """,
        (datos.nit, datos.nombre, datos.telefono, datos.email, datos.activo),
    ).fetchone()
    return obtener_proveedor(conn, fila["id"])


@router.put("/{proveedor_id}")
def actualizar_proveedor(
    proveedor_id: int,
    datos: ProveedorEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    cur = conn.execute(
        """
        UPDATE proveedores
           SET nit = %s, nombre = %s, telefono = %s, email = lower(%s), activo = %s
         WHERE id = %s
        """,
        (datos.nit, datos.nombre, datos.telefono, datos.email, datos.activo, proveedor_id),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    return obtener_proveedor(conn, proveedor_id)


@router.delete("/{proveedor_id}")
def eliminar_proveedor(
    proveedor_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    """Si tiene productos, la FK lo impide y main.py responde 409."""
    cur = conn.execute("DELETE FROM proveedores WHERE id = %s", (proveedor_id,))
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    return {"detail": "Proveedor eliminado"}
