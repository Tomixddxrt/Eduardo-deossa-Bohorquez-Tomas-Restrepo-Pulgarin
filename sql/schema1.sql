-- Creación de la base de datos del proyecto BI
CREATE DATABASE bi_envasado
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Spanish_Colombia.1252'
    LC_CTYPE = 'Spanish_Colombia.1252'
    CONNECTION LIMIT = -1;

    -- ==========================================
-- ESTRUCTURA DEL MODELO DIMENSIONAL (STAGING / BI)
-- ==========================================

-- 1. Dimensión Tiempo / Calendario
CREATE TABLE IF NOT EXISTS dim_tiempo (
    id_fecha DATE PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    dia INT NOT NULL,
    dia_semana VARCHAR(15) NOT NULL,
    semana_anio INT NOT NULL
);

-- 2. Dimensión Línea / Máquina
CREATE TABLE IF NOT EXISTS dim_maquina (
    id_maquina SERIAL PRIMARY KEY,
    nombre_maquina VARCHAR(50) UNIQUE NOT NULL
);

-- 3. Dimensión Operador / Personal
CREATE TABLE IF NOT EXISTS dim_operador (
    id_operador SERIAL PRIMARY KEY,
    nombre_operador VARCHAR(100) UNIQUE NOT NULL
);

-- 4. Dimensión Referencia / Producto
CREATE TABLE IF NOT EXISTS dim_producto (
    id_producto SERIAL PRIMARY KEY,
    nombre_referencia VARCHAR(100) UNIQUE NOT NULL
);

-- 5. Dimensión Catálogo de Paros (Estándar P-MTO-22 / P-MTO-21)
CREATE TABLE IF NOT EXISTS dim_codigo_paro (
    id_codigo_paro SERIAL PRIMARY KEY,
    codigo_oficial VARCHAR(10) UNIQUE NOT NULL,
    descripcion_paro VARCHAR(150) NOT NULL,
    categoria_paro VARCHAR(50)
);

-- 6. Tabla de Hechos: Registros de Producción y Paros
CREATE TABLE IF NOT EXISTS fact_paros_produccion (
    id_hecho BIGSERIAL PRIMARY KEY,
    id_fecha DATE REFERENCES dim_tiempo(id_fecha),
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