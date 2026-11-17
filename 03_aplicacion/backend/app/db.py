"""Pool de conexiones a PostgreSQL (psycopg 3).

La API se conecta como app_ferreteria (DATABASE_URL). Todas las conexiones van
en autocommit: los procedimientos con COMMIT/ROLLBACK (sp_registrar_venta) lo
exigen; si no, PostgreSQL responde "invalid transaction termination".
"""
import os

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

pool = ConnectionPool(
    conninfo=os.environ["DATABASE_URL"],
    min_size=1,
    max_size=10,
    kwargs={"autocommit": True, "row_factory": dict_row},
    check=ConnectionPool.check_connection,  # descarta conexiones caídas
    open=False,  # se abre en el lifespan de main.py
)


def usar_conexion(usuario_id: int | None):
    """Toma una conexión del pool y deja el id del usuario en la sesión.

    El trigger de auditoría lo lee con current_setting('app.usuario_id', true).
    Se fija en cada request porque las conexiones del pool se reutilizan.
    """
    with pool.connection() as conn:
        valor = "" if usuario_id is None else str(usuario_id)
        conn.execute("SELECT set_config('app.usuario_id', %s, false)", (valor,))
        yield conn
