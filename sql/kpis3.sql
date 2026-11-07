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

-- 1. Vista KPI: Productividad por Máquina y Mes
CREATE OR REPLACE VIEW vw_kpi_productividad_mensual AS
SELECT 
    t.anio,
    t.mes,
    t.nombre_mes,
    m.nombre_maquina,
    SUM(f.horas_trabajadas) AS horas_trabajadas,
    SUM(f.horas_sin_trabajar) AS horas_sin_trabajar,
    SUM(f.horas_trabajadas + f.horas_sin_trabajar) AS horas_totales_disponibles,
    ROUND(
        (SUM(f.horas_trabajadas) / NULLIF(SUM(f.horas_trabajadas + f.horas_sin_trabajar), 0)) * 100, 2
    ) AS porcentaje_productividad
FROM fact_paros_produccion f
JOIN dim_tiempo t ON f.id_fecha = t.id_fecha
JOIN dim_maquina m ON f.id_maquina = m.id_maquina
GROUP BY t.anio, t.mes, t.nombre_mes, m.nombre_maquina;

-- 2. Vista KPI: Análisis de Paros por Código Oficial (Pareto)
CREATE OR REPLACE VIEW vw_kpi_pareto_paros AS
SELECT 
    cp.codigo_oficial,
    cp.descripcion_paro,
    cp.categoria_paro,
    ROUND(SUM(f.horas_sin_trabajar), 2) AS total_horas_paro,
    COUNT(f.id_hecho) AS frecuencia_eventos
FROM fact_paros_produccion f
JOIN dim_codigo_paro cp ON f.id_codigo_paro = cp.id_codigo_paro
WHERE cp.codigo_oficial != '[19]' -- Excluir operación normal / no aplica
GROUP BY cp.codigo_oficial, cp.descripcion_paro, cp.categoria_paro
ORDER BY total_horas_paro DESC;

--1. Top 5 Códigos de Paro con Mayor Impacto (Diagrama de Pareto SQL)

SELECT 
    codigo_oficial,
    descripcion_paro,
    categoria_paro,
    total_horas_paro,
    frecuencia_eventos,
    ROUND((total_horas_paro / SUM(total_horas_paro) OVER ()) * 100, 2) AS porcentaje_acumulado
FROM vw_kpi_pareto_paros
LIMIT 5;
--2. % de Productividad Promedio por Máquina
SELECT 
    nombre_maquina,
    ROUND(SUM(horas_trabajadas), 2) AS horas_trabajadas,
    ROUND(SUM(horas_sin_trabajar), 2) AS horas_sin_trabajar,
    ROUND((SUM(horas_trabajadas) / NULLIF(SUM(horas_trabajadas + horas_sin_trabajar), 0)) * 100, 2) AS porcentaje_productividad_global
FROM vw_kpi_productividad_mensual
GROUP BY nombre_maquina
ORDER BY porcentaje_productividad_global DESC;