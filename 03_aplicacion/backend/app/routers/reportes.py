"""Reportes: cada endpoint lee una vista o una función de consultas_reportes.sql.

- stock-bajo:              vw_stock_bajo (alerta del inicio, ambos roles)
- resumen:                 indicadores del inicio (fn_total_venta)
- ventas-categoria-mes:    vw_ventas_categoria_mes (barras)
- top-productos:           vw_top_productos (ranking)
- ventas-detalle:          vw_ventas_detalle (JOIN de 6 tablas)
- clientes-sobre-promedio: fn_reporte_clientes_sobre_promedio (subconsulta)
- categorias-sobre-monto:  fn_reporte_categorias_sobre_monto (GROUP BY + HAVING)
"""
from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, Query

from ..auth import get_conn, require_role

router = APIRouter(prefix="/api/reportes", tags=["reportes"])


@router.get("/stock-bajo")
def stock_bajo(conn=Depends(get_conn), usuario: dict = Depends(require_role("admin", "vendedor"))):
    return conn.execute(
        "SELECT * FROM vw_stock_bajo ORDER BY estado, stock, producto"
    ).fetchall()


@router.get("/resumen")
def resumen(conn=Depends(get_conn), usuario: dict = Depends(require_role("admin"))):
    return conn.execute(
        """
        SELECT
            COALESCE(SUM(fn_total_venta(v.id)) FILTER (WHERE v.fecha >= current_date), 0)
                AS ventas_hoy,
            COUNT(*) FILTER (WHERE v.fecha >= current_date)
                AS numero_ventas_hoy,
            COALESCE(SUM(fn_total_venta(v.id)) FILTER (WHERE v.fecha >= date_trunc('month', current_date)), 0)
                AS ventas_mes,
            COUNT(*) FILTER (WHERE v.fecha >= date_trunc('month', current_date))
                AS numero_ventas_mes,
            (SELECT COUNT(*) FROM productos WHERE activo)  AS productos_activos,
            (SELECT COUNT(*) FROM vw_stock_bajo)           AS productos_stock_bajo
        FROM ventas v
        WHERE v.estado = 'PAGADA'
        """
    ).fetchone()


@router.get("/ventas-categoria-mes")
def ventas_categoria_mes(
    meses: int = Query(default=6, ge=1, le=24),
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    return conn.execute(
        """
        SELECT mes, categoria, unidades, total
        FROM vw_ventas_categoria_mes
        WHERE mes >= date_trunc('month', current_date) - make_interval(months => %s - 1)
        ORDER BY mes, categoria
        """,
        (meses,),
    ).fetchall()


@router.get("/top-productos")
def top_productos(
    limite: int = Query(default=10, ge=1, le=50),
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    return conn.execute(
        "SELECT * FROM vw_top_productos WHERE puesto <= %s ORDER BY puesto, producto",
        (limite,),
    ).fetchall()


@router.get("/ventas-detalle")
def ventas_detalle(
    desde: date | None = None,
    hasta: date | None = None,
    categoria_id: int | None = None,
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    """Filtra por fecha (usa idx_ventas_fecha) y categoría. Solo ventas PAGADAS."""
    return conn.execute(
        """
        SELECT venta_id, fecha, cliente, vendedor, codigo, producto, categoria,
               cantidad, precio_unitario, subtotal
        FROM vw_ventas_detalle
        WHERE estado = 'PAGADA'
          AND (%(desde)s::date IS NULL OR fecha >= %(desde)s::date)
          AND (%(hasta)s::date IS NULL OR fecha < %(hasta)s::date + 1)
          AND (%(categoria_id)s::integer IS NULL OR categoria_id = %(categoria_id)s)
        ORDER BY fecha DESC, venta_id DESC
        """,
        {"desde": desde, "hasta": hasta, "categoria_id": categoria_id},
    ).fetchall()


@router.get("/clientes-sobre-promedio")
def clientes_sobre_promedio(conn=Depends(get_conn), usuario: dict = Depends(require_role("admin"))):
    return conn.execute("SELECT * FROM fn_reporte_clientes_sobre_promedio()").fetchall()


@router.get("/categorias-sobre-monto")
def categorias_sobre_monto(
    monto: Decimal = Query(default=Decimal("500000"), ge=0),
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    return conn.execute(
        "SELECT * FROM fn_reporte_categorias_sobre_monto(%s)", (monto,)
    ).fetchall()
