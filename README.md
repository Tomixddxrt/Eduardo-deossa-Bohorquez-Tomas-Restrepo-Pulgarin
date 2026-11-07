# BI de envasado: despliegue local

PostgreSQL, Grafana y el ETL se levantan juntos con Docker Compose. La base de datos y Grafana conservan sus datos en volúmenes; Grafana aprovisiona al iniciar la fuente PostgreSQL, el tablero y las reglas de alerta.

## Inicio

1. Copia `.env.example` como `.env` y cambia las contraseñas de ejemplo.
2. Desde esta carpeta ejecuta:

   ```powershell
   docker compose up --build -d
   ```

Ese único comando crea/inicia PostgreSQL y Grafana en segundo plano, prepara el esquema y ejecuta el ETL. El servicio `db-init` aplica el SQL de forma idempotente también a volúmenes existentes; el ETL termina normalmente al completar la carga, mientras PostgreSQL y Grafana quedan activos. Para ver su estado usa `docker compose ps -a` y para consultar mensajes `docker compose logs -f`.

Se usa PostgreSQL 15 para ser compatible con los volúmenes de datos existentes creados con PostgreSQL 15. No cambies a PostgreSQL 16 manteniendo ese mismo volumen: las versiones mayores no son compatibles directamente. Conserva los datos con `docker compose down`; no uses `docker compose down -v` salvo que quieras borrar los volúmenes y toda la información.

## Restablecer la contraseña de Grafana

Grafana guarda sus usuarios en el volumen persistente `grafana_data`. Cambiar `GRAFANA_ADMIN_PASSWORD` en `.env` no cambia la contraseña de un administrador que ya existía. Después de cambiarla, ejecuta:

```powershell
docker compose up -d --force-recreate grafana
docker compose exec -T grafana sh -c 'grafana cli admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
```

Inicia sesión con los valores actuales de `GRAFANA_ADMIN_USER` y `GRAFANA_ADMIN_PASSWORD` de `.env`. No borres el volumen para resolver un problema de contraseña, ya que eliminarías el estado persistente de Grafana.

Para ejecutar los simuladores desde PowerShell, usa el mismo intérprete del entorno virtual para instalar y ejecutar. Desde la raíz del proyecto:

```powershell
.\venv\Scripts\python.exe -m pip install -r .\scripts\requirements.txt
.\venv\Scripts\python.exe .\scripts\simulador3alertas.py
```

Si ya estás dentro de `scripts`, usa las rutas relativas a esa carpeta:

```powershell
python -m pip install -r .\requirements.txt
python .\simulador3alertas.py
```

Usa `python`, no `py`, después de activar el entorno virtual: el lanzador `py` puede seleccionar una instalación global diferente. Los simuladores leen automáticamente las credenciales de `.env`.

Los simuladores crean las dimensiones `SIMULACION - Operario` y `SIMULACION - Producto` si aún no existen. Así las pruebas respetan las llaves foráneas sin asumir que una dimensión tiene un ID fijo.

## Acceso desde el equipo anfitrión

- Grafana: <http://localhost:3000> (usuario y contraseña definidos por `GRAFANA_ADMIN_USER` y `GRAFANA_ADMIN_PASSWORD`).
- PostgreSQL para DBeaver o Power BI: host `localhost`, puerto `5432`, base `bi_envasado`, usuario y contraseña `POSTGRES_USER` / `POSTGRES_PASSWORD`.
- El ETL registra la huella del Excel y no vuelve a insertar el mismo archivo. Si reemplazas el Excel y quieres importarlo, elimina solo su registro de `etl_imports` en PostgreSQL antes de volver a ejecutar `docker compose up --build -d`.

Los puertos se pueden cambiar con `GRAFANA_PORT` y `POSTGRES_PORT`. Los puertos internos entre contenedores no cambian.
