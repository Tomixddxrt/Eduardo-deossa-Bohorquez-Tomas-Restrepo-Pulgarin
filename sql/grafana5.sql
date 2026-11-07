--Disponibilidad por máquina
SELECT 
    m.nombre_maquina AS metric,
    ROUND((SUM(f.horas_trabajadas) / NULLIF(SUM(f.horas_trabajadas + f.horas_sin_trabajar), 0)) * 100, 1) AS value
FROM fact_paros_produccion f
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY m.nombre_maquina;

--Horas de paro por máquina
SELECT 
    f.id_fecha AS time,
    m.nombre_maquina AS metric,
    SUM(f.horas_sin_trabajar) AS value
FROM fact_paros_produccion f
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY f.id_fecha, m.nombre_maquina
ORDER BY f.id_fecha ASC;

INSERT INTO dim_tiempo (id_fecha, anio, mes, nombre_mes, dia, dia_semana, semana_anio)
SELECT 
    fecha::DATE AS id_fecha,
    EXTRACT(YEAR FROM fecha) AS anio,
    EXTRACT(MONTH FROM fecha) AS mes,
    TO_CHAR(fecha, 'TMMonth') AS nombre_mes,
    EXTRACT(DAY FROM fecha) AS dia,
    TO_CHAR(fecha, 'TMDay') AS dia_semana,
    EXTRACT(WEEK FROM fecha) AS semana_anio
FROM generate_series('2022-01-01'::date, '2030-12-31'::date, '1 day'::interval) AS fecha
ON CONFLICT (id_fecha) DO NOTHING;