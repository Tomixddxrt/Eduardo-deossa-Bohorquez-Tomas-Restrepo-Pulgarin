-- Base de datos BI de envasado. POSTGRES_DB se crea con las variables del contenedor.
-- Este archivo se ejecuta una vez al inicializar un volumen PostgreSQL nuevo.

CREATE TABLE IF NOT EXISTS dim_tiempo (
    id_fecha DATE PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    dia INT NOT NULL,
    dia_semana VARCHAR(15) NOT NULL,
    semana_anio INT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_maquina (
    id_maquina SERIAL PRIMARY KEY,
    nombre_maquina VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_operador (
    id_operador SERIAL PRIMARY KEY,
    nombre_operador VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_producto (
    id_producto SERIAL PRIMARY KEY,
    nombre_referencia VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_codigo_paro (
    id_codigo_paro SERIAL PRIMARY KEY,
    codigo_oficial VARCHAR(10) UNIQUE NOT NULL,
    descripcion_paro VARCHAR(150) NOT NULL,
    categoria_paro VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS fact_paros_produccion (
    id_hecho BIGSERIAL PRIMARY KEY,
    id_fecha DATE REFERENCES dim_tiempo(id_fecha),
    fecha_hora TIMESTAMP,
    id_maquina INT REFERENCES dim_maquina(id_maquina),
    id_operador INT REFERENCES dim_operador(id_operador),
    id_producto INT REFERENCES dim_producto(id_producto),
    id_codigo_paro INT REFERENCES dim_codigo_paro(id_codigo_paro),
    turno INT,
    horas_trabajadas NUMERIC(5,2),
    meta_por_hora NUMERIC(10,2),
    pacas_producidas NUMERIC(10,2),
    horas_sin_trabajar NUMERIC(5,2),
    subcodigo_original VARCHAR(50),
    observacion TEXT
);

ALTER TABLE fact_paros_produccion
    ADD COLUMN IF NOT EXISTS fecha_hora TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_fact_paros_fecha_hora
    ON fact_paros_produccion (fecha_hora);

CREATE TABLE IF NOT EXISTS etl_imports (
    source_name TEXT PRIMARY KEY,
    source_sha256 CHAR(64) NOT NULL,
    imported_rows BIGINT NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dim_codigo_paro (codigo_oficial, descripcion_paro, categoria_paro) VALUES
('[01]', 'Falla del sistema electromecánico y/o de control', 'Mantenimiento'),
('[02]', 'Espera de soporte de mantenimiento', 'Mantenimiento'),
('[03]', 'Novedad del suministro energético o de potencia', 'Servicios General'),
('[04]', 'Novedades de la red de aire comprimido / neumática', 'Servicios General'),
('[05]', 'Ajuste operativo o cambio de lote / formato', 'Operaciones'),
('[06]', 'Falta o retraso de insumos / granel', 'Logística / Abastecimiento'),
('[07]', 'Pruebas de calidad / liberación de línea', 'Calidad'),
('[08]', 'Limpieza y aseo de la línea / cambio de producto', 'Operaciones'),
('[09]', 'Ausencia de personal / rotación / inducción', 'Gestión Humana'),
('[10]', 'Reunión de equipo / capacitación', 'Gestión Humana'),
('[11]', 'Pausas activas / descanso reglamentario', 'Gestión Humana'),
('[12]', 'Novedad en la materia prima / material defectuoso', 'Calidad / Proveedores'),
('[13]', 'Falla en herramientas o equipos auxiliares', 'Mantenimiento'),
('[14]', 'Daño en empaque secundario / codificado', 'Calidad'),
('[15]', 'Falta de espacio en bodega / saturación de línea', 'Logística'),
('[16]', 'Falla por mal manejo operativo', 'Operaciones'),
('[17]', 'Mantenimiento programado / preventivo', 'Mantenimiento'),
('[18]', 'Otros paros no clasificados', 'Otros'),
('[19]', 'No aplica / Operación normal', 'Sin Paro')
ON CONFLICT (codigo_oficial) DO NOTHING;

INSERT INTO dim_maquina (nombre_maquina) VALUES
('Vinilos_1'), ('Vinilos_2'), ('Vinilos_3'), ('Vinilos_4')
ON CONFLICT (nombre_maquina) DO NOTHING;

INSERT INTO dim_tiempo (id_fecha, anio, mes, nombre_mes, dia, dia_semana, semana_anio)
SELECT fecha::DATE,
       EXTRACT(YEAR FROM fecha)::INT,
       EXTRACT(MONTH FROM fecha)::INT,
       TO_CHAR(fecha, 'TMMonth'),
       EXTRACT(DAY FROM fecha)::INT,
       TO_CHAR(fecha, 'TMDay'),
       EXTRACT(WEEK FROM fecha)::INT
FROM generate_series('2022-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS fecha
ON CONFLICT (id_fecha) DO NOTHING;

CREATE OR REPLACE VIEW vw_kpi_oee_detalle AS
SELECT
    f.id_hecho,
    f.id_fecha,
    t.anio,
    t.mes,
    t.nombre_mes,
    m.nombre_maquina,
    p.nombre_referencia,
    op.nombre_operador,
    f.horas_trabajadas,
    f.horas_sin_trabajar AS horas_paro,
    (f.horas_trabajadas + f.horas_sin_trabajar) AS horas_disponibles,
    f.pacas_producidas,
    COALESCE(f.meta_por_hora, 50.0) AS meta_por_hora,
    ROUND((f.horas_trabajadas /
        NULLIF(f.horas_trabajadas + f.horas_sin_trabajar, 0))::NUMERIC, 4) AS disponibilidad,
    ROUND((f.pacas_producidas /
        NULLIF(COALESCE(f.meta_por_hora, 50.0) * f.horas_trabajadas, 0))::NUMERIC, 4) AS rendimiento,
    1.0000 AS calidad,
    ROUND((
        (f.horas_trabajadas / NULLIF(f.horas_trabajadas + f.horas_sin_trabajar, 0)) *
        (f.pacas_producidas / NULLIF(COALESCE(f.meta_por_hora, 50.0) * f.horas_trabajadas, 0))
    )::NUMERIC, 4) AS oee
FROM fact_paros_produccion f
JOIN dim_tiempo t ON f.id_fecha = t.id_fecha
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
LEFT JOIN dim_producto p ON f.id_producto = p.id_producto
LEFT JOIN dim_operador op ON f.id_operador = op.id_operador;

CREATE OR REPLACE VIEW vw_kpi_productividad_mensual AS
SELECT
    t.anio,
    t.mes,
    t.nombre_mes,
    m.nombre_maquina,
    SUM(f.horas_trabajadas) AS horas_trabajadas,
    SUM(f.horas_sin_trabajar) AS horas_sin_trabajar,
    SUM(f.horas_trabajadas + f.horas_sin_trabajar) AS horas_totales_disponibles,
    ROUND((SUM(f.horas_trabajadas) /
        NULLIF(SUM(f.horas_trabajadas + f.horas_sin_trabajar), 0)) * 100, 2) AS porcentaje_productividad
FROM fact_paros_produccion f
JOIN dim_tiempo t ON f.id_fecha = t.id_fecha
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY t.anio, t.mes, t.nombre_mes, m.nombre_maquina;

CREATE OR REPLACE VIEW vw_kpi_pareto_paros AS
SELECT
    cp.codigo_oficial,
    cp.descripcion_paro,
    cp.categoria_paro,
    ROUND(SUM(f.horas_sin_trabajar), 2) AS total_horas_paro,
    COUNT(f.id_hecho) AS frecuencia_eventos
FROM fact_paros_produccion f
JOIN dim_codigo_paro cp ON f.id_codigo_paro = cp.id_codigo_paro
WHERE cp.codigo_oficial <> '[19]'
GROUP BY cp.codigo_oficial, cp.descripcion_paro, cp.categoria_paro;

-- Consultas de análisis de kpis3.sql.
SELECT
    m.nombre_maquina,
    COUNT(f.id_hecho) AS total_registros,
    ROUND(SUM(f.horas_trabajadas), 2) AS total_horas_trabajadas,
    ROUND(SUM(f.horas_sin_trabajar), 2) AS total_horas_paradas,
    ROUND(SUM(f.pacas_producidas), 0) AS total_pacas_producidas
FROM fact_paros_produccion f
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY m.nombre_maquina
ORDER BY m.nombre_maquina;

SELECT
    codigo_oficial,
    descripcion_paro,
    categoria_paro,
    total_horas_paro,
    frecuencia_eventos,
    ROUND((total_horas_paro / NULLIF(SUM(total_horas_paro) OVER (), 0)) * 100, 2) AS porcentaje_acumulado
FROM vw_kpi_pareto_paros
ORDER BY total_horas_paro DESC
LIMIT 5;

SELECT
    nombre_maquina,
    ROUND(SUM(horas_trabajadas), 2) AS horas_trabajadas,
    ROUND(SUM(horas_sin_trabajar), 2) AS horas_sin_trabajar,
    ROUND((SUM(horas_trabajadas) /
        NULLIF(SUM(horas_trabajadas + horas_sin_trabajar), 0)) * 100, 2) AS porcentaje_productividad_global
FROM vw_kpi_productividad_mensual
GROUP BY nombre_maquina
ORDER BY porcentaje_productividad_global DESC;

-- Consultas usadas por Grafana.
SELECT
    m.nombre_maquina AS metric,
    ROUND((SUM(f.horas_trabajadas) /
        NULLIF(SUM(f.horas_trabajadas + f.horas_sin_trabajar), 0)) * 100, 1) AS value
FROM fact_paros_produccion f
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY m.nombre_maquina;

SELECT
    f.id_fecha AS time,
    m.nombre_maquina AS metric,
    SUM(f.horas_sin_trabajar) AS value
FROM fact_paros_produccion f
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY f.id_fecha, m.nombre_maquina
ORDER BY f.id_fecha;
