"""Punto de entrada de la API (FastAPI).

- Abre/cierra el pool de conexiones con la app.
- Traduce errores de la BD y de validación a {"detail": "mensaje en español"}.
- Registra los routers de cada módulo (cada integrante en su sección).
"""
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from psycopg import errors
from starlette.exceptions import HTTPException as StarletteHTTPException

from .db import pool
from .routers import auth, categorias, productos, ventas


@asynccontextmanager
async def lifespan(app: FastAPI):
    pool.open(wait=True, timeout=30)
    yield
    pool.close()


app = FastAPI(title="Ferretería El Bachué - API", version="1.0.0", lifespan=lifespan)


# =====================================================================
# Manejo de errores
# =====================================================================
def responder(codigo: int, mensaje: str) -> JSONResponse:
    return JSONResponse(status_code=codigo, content={"detail": mensaje})


@app.exception_handler(errors.RaiseException)
async def error_raise(request: Request, exc: errors.RaiseException):
    """Error controlado: RAISE EXCEPTION de un procedimiento o trigger (SQLSTATE P0001).
    Se devuelve tal cual el mensaje que escribió la BD (ej. 'Stock insuficiente ...')."""
    return responder(400, exc.diag.message_primary or "Operación rechazada por la base de datos")


@app.exception_handler(errors.UniqueViolation)
async def error_unico(request: Request, exc: errors.UniqueViolation):
    return responder(409, "Ya existe un registro con ese valor (código, documento, NIT, correo o nombre repetido)")


@app.exception_handler(errors.ForeignKeyViolation)
async def error_fk(request: Request, exc: errors.ForeignKeyViolation):
    mensaje = exc.diag.message_primary or ""
    if mensaje.startswith("update or delete"):
        return responder(409, "No se puede eliminar: el registro tiene datos relacionados (ventas, productos o movimientos). Puede desactivarlo.")
    return responder(400, "Uno de los registros relacionados no existe")


@app.exception_handler(errors.CheckViolation)
async def error_check(request: Request, exc: errors.CheckViolation):
    return responder(400, "Un valor no cumple las reglas de la base de datos (revise cantidades, precios y formatos)")


@app.exception_handler(errors.NotNullViolation)
async def error_not_null(request: Request, exc: errors.NotNullViolation):
    return responder(400, "Falta un dato obligatorio")


@app.exception_handler(psycopg.Error)
async def error_bd(request: Request, exc: psycopg.Error):
    return responder(500, "Error en la base de datos. Intente de nuevo.")


# Errores HTTP genéricos de FastAPI/Starlette (vienen en inglés)
MENSAJES_HTTP = {
    "Not Found": "Recurso no encontrado",
    "Method Not Allowed": "Método no permitido",
    "There was an error parsing the body": "El cuerpo de la petición no es válido",
}


@app.exception_handler(StarletteHTTPException)
async def error_http(request: Request, exc: StarletteHTTPException):
    detalle = MENSAJES_HTTP.get(exc.detail, exc.detail) if isinstance(exc.detail, str) else exc.detail
    return JSONResponse(status_code=exc.status_code, content={"detail": detalle},
                        headers=getattr(exc, "headers", None))


# Errores 422 de Pydantic traducidos al español
MENSAJES_VALIDACION = {
    "missing": "es obligatorio",
    "string_too_short": "debe tener al menos {min_length} caracteres",
    "string_too_long": "debe tener máximo {max_length} caracteres",
    "string_pattern_mismatch": "tiene un formato inválido",
    "string_type": "debe ser texto",
    "int_parsing": "debe ser un número entero",
    "int_type": "debe ser un número entero",
    "int_from_float": "debe ser un número entero",
    "float_parsing": "debe ser un número",
    "decimal_parsing": "debe ser un número",
    "decimal_max_places": "debe tener máximo {decimal_places} decimales",
    "greater_than": "debe ser mayor que {gt}",
    "greater_than_equal": "debe ser mayor o igual que {ge}",
    "less_than": "debe ser menor que {lt}",
    "less_than_equal": "debe ser menor o igual que {le}",
    "bool_parsing": "debe ser verdadero o falso",
    "list_type": "debe ser una lista",
    "too_short": "debe tener al menos {min_length} elemento(s)",
    "date_from_datetime_parsing": "debe ser una fecha válida (AAAA-MM-DD)",
    "date_parsing": "debe ser una fecha válida (AAAA-MM-DD)",
    "json_invalid": "el cuerpo de la petición no es un JSON válido",
    "model_attributes_type": "debe ser un objeto",
}


@app.exception_handler(RequestValidationError)
async def error_validacion(request: Request, exc: RequestValidationError):
    partes = []
    for error in exc.errors():
        campo = ".".join(str(x) for x in error["loc"] if x not in ("body", "query", "path"))
        if error["type"] == "json_invalid":
            campo = ""  # el loc es la posición del error en el texto, no un campo
        plantilla = MENSAJES_VALIDACION.get(error["type"])
        if plantilla:
            try:
                mensaje = plantilla.format(**error.get("ctx", {}))
            except (KeyError, IndexError):
                mensaje = "tiene un valor inválido"
        elif error["type"] == "value_error" and "email" in error.get("msg", "").lower():
            mensaje = "no es un correo válido"
        else:
            mensaje = "tiene un valor inválido"
        partes.append(f"{campo}: {mensaje}" if campo else mensaje)
    return responder(422, "; ".join(partes))


# =====================================================================
# Routers - sección Johan
# =====================================================================
app.include_router(auth.router)
app.include_router(productos.router)
app.include_router(categorias.router)
app.include_router(ventas.router)


# =====================================================================
# Routers - sección Michel
# =====================================================================
