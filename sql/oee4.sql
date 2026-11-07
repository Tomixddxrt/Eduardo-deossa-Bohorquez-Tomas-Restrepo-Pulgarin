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
    -- Factor 1: Disponibilidad
    ROUND(
        (f.horas_trabajadas / NULLIF(f.horas_trabajadas + f.horas_sin_trabajar, 0))::numeric, 4
    ) AS disponibilidad,
    -- Factor 2: Rendimiento
    ROUND(
        (f.pacas_producidas / NULLIF(COALESCE(f.meta_por_hora, 50.0) * f.horas_trabajadas, 0))::numeric, 4
    ) AS rendimiento,
    -- Factor 3: Calidad (1.00 por defecto)
    1.0000 AS calidad,
    -- OEE Calculado
    ROUND(
        (
            (f.horas_trabajadas / NULLIF(f.horas_trabajadas + f.horas_sin_trabajar, 0)) *
            (f.pacas_producidas / NULLIF(COALESCE(f.meta_por_hora, 50.0) * f.horas_trabajadas, 0)) *
            1.0000
        )::numeric, 4
    ) AS oee
FROM fact_paros_produccion f
JOIN dim_tiempo t ON f.id_fecha = t.id_fecha
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
LEFT JOIN dim_producto p ON f.id_producto = p.id_producto
LEFT JOIN dim_operador op ON f.id_operador = op.id_operador;