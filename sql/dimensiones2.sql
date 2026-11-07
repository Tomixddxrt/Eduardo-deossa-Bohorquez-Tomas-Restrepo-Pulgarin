-- 1. Insertar Catálogo Oficial de Códigos de Paro (18 Códigos Estándar)
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
('[18]', 'Otros paros no clasificados', 'Otros')
ON CONFLICT (codigo_oficial) DO NOTHING;

-- 2. Insertar Máquinas / Líneas de Envasado
INSERT INTO dim_maquina (nombre_maquina) VALUES
('Vinilos_1'),
('Vinilos_2'),
('Vinilos_3'),
('Vinilos_4')
ON CONFLICT (nombre_maquina) DO NOTHING;

-- 1. Ampliar el rango de fechas en dim_tiempo para incluir desde el 2022
INSERT INTO dim_tiempo (id_fecha, anio, mes, nombre_mes, dia, dia_semana, semana_anio)
SELECT 
    fecha::DATE AS id_fecha,
    EXTRACT(YEAR FROM fecha) AS anio,
    EXTRACT(MONTH FROM fecha) AS mes,
    TO_CHAR(fecha, 'TMMonth') AS nombre_mes,
    EXTRACT(DAY FROM fecha) AS dia,
    TO_CHAR(fecha, 'TMDay') AS dia_semana,
    EXTRACT(WEEK FROM fecha) AS semana_anio
FROM generate_series('2022-01-01'::date, '2025-12-31'::date, '1 day'::interval) AS fecha
ON CONFLICT (id_fecha) DO NOTHING;

-- 2. Agregar el código de paro [19] No aplica
INSERT INTO dim_codigo_paro (codigo_oficial, descripcion_paro, categoria_paro)
VALUES ('[19]', 'No aplica / Operación normal', 'Sin Paro')
ON CONFLICT (codigo_oficial) DO NOTHING;