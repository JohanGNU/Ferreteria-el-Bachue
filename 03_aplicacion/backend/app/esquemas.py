"""Modelo base de Pydantic para los cuerpos de las peticiones.

Quita espacios al inicio y al final de los textos y descarta los campos vacíos
(""), que llegan así desde los formularios: un campo obligatorio vacío da
"es obligatorio" y uno opcional vacío queda en None.
"""
from typing import Any

from pydantic import BaseModel, model_validator


class Entrada(BaseModel):
    @model_validator(mode="before")
    @classmethod
    def limpiar_textos(cls, datos: Any) -> Any:
        if not isinstance(datos, dict):
            return datos
        limpio = {}
        for clave, valor in datos.items():
            if isinstance(valor, str):
                valor = valor.strip()
                if valor == "":
                    continue
            limpio[clave] = valor
        return limpio
