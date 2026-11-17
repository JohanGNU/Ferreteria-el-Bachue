"""Consulta de la auditoría (solo admin, solo lectura).

La tabla la llena trg_auditoria; app_ferreteria no puede escribir en ella.
LEFT JOIN a usuarios porque auditoria no tiene FK (el usuario pudo borrarse).
"""
from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, Query

from ..auth import get_conn, require_role

router = APIRouter(prefix="/api/auditoria", tags=["auditoria"])


@router.get("")
def listar_auditoria(
    tabla: Literal["productos", "clientes", "usuarios"] | None = None,
    operacion: Literal["INSERT", "UPDATE", "DELETE"] | None = None,
    desde: date | None = None,
    hasta: date | None = None,
    limite: int = Query(default=200, ge=1, le=1000),
    conn=Depends(get_conn),
    usuario: dict = Depends(require_role("admin")),
):
    return conn.execute(
        """
        SELECT a.id, a.fecha, a.tabla, a.operacion, a.registro_id,
               a.usuario_id, COALESCE(u.nombre, 'Sistema') AS usuario,
               a.datos_antes, a.datos_despues
        FROM auditoria a
        LEFT JOIN usuarios u ON u.id = a.usuario_id
        WHERE (%(tabla)s::text IS NULL OR a.tabla = %(tabla)s)
          AND (%(operacion)s::text IS NULL OR a.operacion = %(operacion)s)
          AND (%(desde)s::date IS NULL OR a.fecha >= %(desde)s::date)
          AND (%(hasta)s::date IS NULL OR a.fecha < %(hasta)s::date + 1)
        ORDER BY a.id DESC
        LIMIT %(limite)s
        """,
        {"tabla": tabla, "operacion": operacion, "desde": desde, "hasta": hasta, "limite": limite},
    ).fetchall()
