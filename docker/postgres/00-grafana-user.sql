\getenv postgres_db POSTGRES_DB
\getenv postgres_user POSTGRES_USER
\getenv grafana_db_user GRAFANA_DB_USER
\getenv grafana_db_password GRAFANA_DB_PASSWORD

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'grafana_db_user', :'grafana_db_password')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = :'grafana_db_user'
)
\gexec

ALTER ROLE :"grafana_db_user" WITH LOGIN PASSWORD :'grafana_db_password';
GRANT CONNECT ON DATABASE :"postgres_db" TO :"grafana_db_user";
GRANT USAGE ON SCHEMA public TO :"grafana_db_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"grafana_db_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"postgres_user" IN SCHEMA public
    GRANT SELECT ON TABLES TO :"grafana_db_user";
