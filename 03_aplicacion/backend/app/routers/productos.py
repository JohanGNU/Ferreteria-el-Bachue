"""CRUD de productos.

Crear y editar van por procedimiento almacenado (sp_crear_producto con OUT,
sp_actualizar_producto). El listado usa fn_estado_stock para la columna Estado.
admin: todo. vendedor: solo lectura.
"""
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import Field

from ..esquemas import Entrada
from ..auth import get_conn, require_role
from ..db import patron_busqueda

router = APIRouter(prefix="/api/productos", tags=["productos"])

SQL_PRODUCTOS = """
    SELECT p.id, p.codigo, p.nombre,
           p.categoria_id, c.nombre AS categoria,
           p.proveedor_id, pr.nombre AS proveedor,
           p.precio_compra, p.precio_venta, p.stock, p.stock_minimo, p.activo,
           fn_estado_stock(p.stock, p.stock_minimo) AS estado_stock
    FROM productos p
    JOIN categorias  c  ON c.id  = p.categoria_id
    JOIN proveedores pr ON pr.id = p.proveedor_id
"""


class ProductoBase(Entrada):
    codigo: str = Field(min_length=1, max_length=20, pattern=r"^[A-Za-z0-9-]+$")
    nombre: str = Field(min_length=2, max_length=120)
    categoria_id: int = Field(gt=0)
    proveedor_id: int = Field(gt=0)
    precio_compra: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    precio_venta: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    stock_minimo: int = Field(default=5, ge=0)


class ProductoCrear(ProductoBase):
    stock: int = Field(default=0, ge=0)  # stock inicial: queda como ENTRADA en el kardex


class ProductoActualizar(ProductoBase):
    activo: bool = True  # el stock no se edita aquí: solo cambia con ventas y entradas


def obtener_producto(conn, producto_id: int) -> dict:
    producto = conn.execute(SQL_PRODUCTOS + " WHERE p.id = %s", (producto_id,)).fetchone()
    if producto is None:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    return producto


@router.get("")
def listar_productos(
    q: str | None = None,
    solo_activos: bool = False,
    proveedor_id: int | None = None,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    """Búsqueda por nombre o código (ILIKE, apoyada en idx_productos_nombre_trgm)."""
    return conn.execute(
        SQL_PRODUCTOS
        + """
        WHERE (%(patron)s::text IS NULL OR p.nombre ILIKE %(patron)s OR p.codigo ILIKE %(patron)s)
          AND (NOT %(solo_activos)s OR p.activo)
          AND (%(proveedor_id)s::integer IS NULL OR p.proveedor_id = %(proveedor_id)s)
        ORDER BY p.nombre
        """,
        {"patron": patron_busqueda(q), "solo_activos": solo_activos, "proveedor_id": proveedor_id},
    ).fetchall()


@router.get("/{producto_id}")
def ver_producto(
    producto_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    return obtener_producto(conn, producto_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_producto(
    datos: ProductoCrear,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    # CALL con el OUT en NULL; fetchone() trae {"p_producto_id": id}
    fila = conn.execute(
        "CALL sp_crear_producto(%s, %s, %s, %s, %s, %s, %s, %s, %s, NULL)",
        (
            datos.codigo, datos.nombre, datos.categoria_id, datos.proveedor_id,
            datos.precio_compra, datos.precio_venta, datos.stock, datos.stock_minimo,
            usuario["id"],
        ),
    ).fetchone()
    return obtener_producto(conn, fila["p_producto_id"])


@router.put("/{producto_id}")
def actualizar_producto(
    producto_id: int,
    datos: ProductoActualizar,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    conn.execute(
        "CALL sp_actualizar_producto(%s, %s, %s, %s, %s, %s, %s, %s, %s)",
        (
            producto_id, datos.codigo, datos.nombre, datos.categoria_id, datos.proveedor_id,
            datos.precio_compra, datos.precio_venta, datos.stock_minimo, datos.activo,
        ),
    )
    return obtener_producto(conn, producto_id)


class EntradaMercancia(Entrada):
    cantidad: int = Field(gt=0, le=100000)


@router.post("/{producto_id}/entradas")
def registrar_entrada(
    producto_id: int,
    datos: EntradaMercancia,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    """Entrada de mercancía vía sp_registrar_entrada (suma stock + kardex ENTRADA).
    Se usa desde la pantalla de proveedores."""
    conn.execute(
        "CALL sp_registrar_entrada(%s, %s, %s)",
        (producto_id, datos.cantidad, usuario["id"]),
    )
    return obtener_producto(conn, producto_id)


@router.delete("/{producto_id}")
def eliminar_producto(
    producto_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    """Si el producto tiene ventas, la FK lo impide y main.py responde 409."""
    cur = conn.execute("DELETE FROM productos WHERE id = %s", (producto_id,))
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    return {"detail": "Producto eliminado"}
