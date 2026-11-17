#!/bin/bash
# =====================================================================
# Ferretería El Bachué - usuario de la aplicación (init 05)
# Crea el rol app_ferreteria con permisos limitados (sin superusuario,
# sin CREATE, sin escritura en auditoria). Corre después de crear
# tablas, rutinas, vistas y datos, por eso los GRANT ... ON ALL los cubren.
# Las credenciales vienen de .env (APP_DB_USER, APP_DB_PASSWORD).
# =====================================================================
set -e

# Las variables se pasan a psql con -v y se usan como :"x" (identificador)
# y :'x' (literal): psql las escapa, no se concatena texto en el SQL.
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
     -v app_user="$APP_DB_USER" \
     -v app_pass="$APP_DB_PASSWORD" \
     -v db_name="$POSTGRES_DB" <<'EOSQL'

-- Usuario de login sin privilegios especiales
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_pass'
    NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Conexión y uso del esquema
GRANT CONNECT ON DATABASE :"db_name" TO :"app_user";
GRANT USAGE ON SCHEMA public TO :"app_user";

-- CRUD sobre tablas, secuencias de las identidades y ejecución de rutinas
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"app_user";
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO :"app_user";

-- Lo mismo para objetos que se creen después
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"app_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"app_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON ROUTINES TO :"app_user";

-- La auditoría solo la escribe el trigger (SECURITY DEFINER).
-- La app puede leerla, pero no insertar, modificar ni borrar.
REVOKE INSERT, UPDATE, DELETE ON auditoria FROM :"app_user";
EOSQL

echo "Usuario $APP_DB_USER creado con permisos limitados"
