"""Ventas: registrar (sp_registrar_venta), listar con total (fn_total_venta),
ver detalle y anular (sp_anular_venta).

admin: todo. vendedor: crear, listar y ver detalle (no anula).
"""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from psycopg.types.json import Jsonb
from pydantic import Field

from ..esquemas import Entrada
from ..auth import get_conn, require_role
from ..db import patron_busqueda

router = APIRouter(prefix="/api/ventas", tags=["ventas"])


class ItemVenta(Entrada):
    producto_id: int = Field(gt=0)
    cantidad: int = Field(gt=0)


class VentaEntrada(Entrada):
    cliente_id: int = Field(gt=0)
    items: list[ItemVenta] = Field(min_length=1)


def obtener_venta(conn, venta_id: int) -> dict:
    venta = conn.execute(
        """
        SELECT v.id, v.fecha, v.estado,
               v.cliente_id, c.nombre AS cliente, c.documento AS cliente_documento,
               v.usuario_id, u.nombre AS vendedor,
               fn_total_venta(v.id) AS total
        FROM ventas v
        JOIN clientes c ON c.id = v.cliente_id
        JOIN usuarios u ON u.id = v.usuario_id
        WHERE v.id = %s
        """,
        (venta_id,),
    ).fetchone()
    if venta is None:
        raise HTTPException(status_code=404, detail="Venta no encontrada")

    venta["items"] = conn.execute(
        """
        SELECT d.producto_id, p.codigo, p.nombre AS producto,
               d.cantidad, d.precio_unitario,
               d.cantidad * d.precio_unitario AS subtotal
        FROM detalle_venta d
        JOIN productos p ON p.id = d.producto_id
        WHERE d.venta_id = %s
        ORDER BY d.id
        """,
        (venta_id,),
    ).fetchall()
    venta["subtotal"] = sum(item["subtotal"] for item in venta["items"])
    venta["iva"] = venta["total"] - venta["subtotal"]
    return venta


@router.get("")
def listar_ventas(
    q: str | None = None,
    desde: date | None = None,
    hasta: date | None = None,
    estado: str | None = None,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    """Filtros: q (cliente o documento), rango de fechas (usa idx_ventas_fecha) y estado."""
    return conn.execute(
        """
        SELECT v.id, v.fecha, v.estado,
               c.nombre AS cliente, c.documento AS cliente_documento,
               u.nombre AS vendedor,
               fn_total_venta(v.id) AS total
        FROM ventas v
        JOIN clientes c ON c.id = v.cliente_id
        JOIN usuarios u ON u.id = v.usuario_id
        WHERE (%(patron)s::text IS NULL OR c.nombre ILIKE %(patron)s OR c.documento ILIKE %(patron)s)
          AND (%(desde)s::date IS NULL OR v.fecha >= %(desde)s::date)
          AND (%(hasta)s::date IS NULL OR v.fecha < %(hasta)s::date + 1)
          AND (%(estado)s::text IS NULL OR v.estado = upper(%(estado)s))
        ORDER BY v.fecha DESC
        """,
        {"patron": patron_busqueda(q), "desde": desde, "hasta": hasta, "estado": estado or None},
    ).fetchall()


@router.get("/{venta_id}")
def ver_venta(
    venta_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    return obtener_venta(conn, venta_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def registrar_venta(
    datos: VentaEntrada,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin", "vendedor")),
):
    """Toda la transacción ocurre en sp_registrar_venta (COMMIT o ROLLBACK + RAISE).
    Si falta stock, el RAISE llega como RaiseException y main.py responde 400."""
    items = [item.model_dump() for item in datos.items]
    fila = conn.execute(
        "CALL sp_registrar_venta(%s, %s, %s, NULL)",
        (datos.cliente_id, usuario["id"], Jsonb(items)),
    ).fetchone()
    return obtener_venta(conn, fila["p_venta_id"])


@router.post("/{venta_id}/anular")
def anular_venta(
    venta_id: int,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    conn.execute("CALL sp_anular_venta(%s, %s)", (venta_id, usuario["id"]))
    return obtener_venta(conn, venta_id)
