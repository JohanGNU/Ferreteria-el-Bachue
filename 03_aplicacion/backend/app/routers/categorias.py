"""CRUD de categorías (SQL directo con parámetros).

admin: todo. vendedor: solo lectura (las usa como filtro de productos).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import Field

from ..esquemas import Entrada
from ..auth import get_conn, require_role
from ..db import patron_busqueda

router = APIRouter(prefix="/api/categorias", tags=["categorias"])

SQL_CATEGORIAS = """
    SELECT c.id, c.nombre, c.descripcion, count(p.id) AS total_productos
    FROM categorias c
    LEFT JOIN productos p ON p.categoria_id = c.id
"""


class CategoriaEntrada(Entrada):
    nombre: str = Field(min_length=2, max_length=60)
    descripcion: str | None = Field(default=None, max_length=500)


def obtener_categoria(conn, categoria_id: int) -> dict:
    categoria = conn.execute(
        SQL_CATEGORIAS + " WHERE c.id = %s GROUP BY c.id", (categoria_id,)
    ).fetchone()
    if categoria is None:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    return categoria


@router.get("")
def listar_categorias(
    q: str | None = None,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    return conn.execute(
        SQL_CATEGORIAS
        + """
        WHERE (%(patron)s::text IS NULL OR c.nombre ILIKE %(patron)s OR c.descripcion ILIKE %(patron)s)
        GROUP BY c.id
        ORDER BY c.nombre
        """,
        {"patron": patron_busqueda(q)},
    ).fetchall()


@router.get("/{categoria_id}")
def ver_categoria(
    categoria_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    return obtener_categoria(conn, categoria_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_categoria(
    datos: CategoriaEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    fila = conn.execute(
        "INSERT INTO categorias (nombre, descripcion) VALUES (%s, %s) RETURNING id",
        (datos.nombre.strip(), datos.descripcion),
    ).fetchone()
    return obtener_categoria(conn, fila["id"])


@router.put("/{categoria_id}")
def actualizar_categoria(
    categoria_id: int,
    datos: CategoriaEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    cur = conn.execute(
        "UPDATE categorias SET nombre = %s, descripcion = %s WHERE id = %s",
        (datos.nombre.strip(), datos.descripcion, categoria_id),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    return obtener_categoria(conn, categoria_id)


@router.delete("/{categoria_id}")
def eliminar_categoria(
    categoria_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    """Si tiene productos, la FK lo impide y main.py responde 409."""
    cur = conn.execute("DELETE FROM categorias WHERE id = %s", (categoria_id,))
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    return {"detail": "Categoría eliminada"}
