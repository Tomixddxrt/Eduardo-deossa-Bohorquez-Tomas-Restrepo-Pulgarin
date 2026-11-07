import time
import random
from datetime import datetime, timedelta
from sqlalchemy import text
from db_connection import create_database_engine
from simulation_dimensions import ensure_simulation_dimensions

engine = create_database_engine()

print("="*65)
print("🚀 CARGA PROGRESIVA DE HISTORIAL (SEPTIEMBRE A NOVIEMBRE 2026)")
print("="*65)

fecha_inicio = datetime(2026, 9, 1)
fecha_fin = datetime(2026, 11, 5)  # Carga hasta el día de ayer
fecha_actual = fecha_inicio
registros_creados = 0

try:
    with engine.begin() as conn:
        dimensions = ensure_simulation_dimensions(conn)

    while fecha_actual <= fecha_fin:
        id_fecha = fecha_actual.date()
        
        # 1. Garantizar dim_tiempo para la fecha procesada
        with engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO dim_tiempo (id_fecha, anio, mes, nombre_mes, dia, dia_semana, semana_anio)
                VALUES (:fecha, :anio, :mes, :nombre_mes, :dia, :dia_semana, :semana)
                ON CONFLICT (id_fecha) DO NOTHING;
            """), {
                "fecha": id_fecha, "anio": id_fecha.year, "mes": id_fecha.month,
                "nombre_mes": id_fecha.strftime('%B'), "dia": id_fecha.day,
                "dia_semana": id_fecha.strftime('%A'), "semana": id_fecha.isocalendar()[1]
            })
        
        # 2. Insertar registros para 2 turnos diarios por cada línea
        for hora in [6, 14]:  # Turnos 6:00 AM y 2:00 PM
            ts = datetime.combine(id_fecha, datetime.min.time()) + timedelta(hours=hora)
            for maquina_id in dimensions.machines.values():
                codigo_paro = random.choice(["[01]", "[02]", "[05]", "[14]", "[19]", "[19]", "[19]"])
                if codigo_paro == "[19]":
                    h_trab, h_paro, pacas, obs = 7.5, 0.5, random.randint(350, 420), "Turno normal de producción"
                else:
                    h_trab = round(random.uniform(3.0, 6.0), 2)
                    h_paro = round(8.0 - h_trab, 2)
                    pacas = int(h_trab * 50)
                    obs = "Paro operativo registrado en turno"

                with engine.begin() as conn:
                    conn.execute(text("""
                        INSERT INTO fact_paros_produccion (
                            id_fecha, fecha_hora, id_maquina, id_operador, id_producto, 
                            id_codigo_paro, horas_trabajadas, pacas_producidas, 
                            horas_sin_trabajar, observacion
                        ) VALUES (
                            :fecha, :ts, :maq, :operador, :producto, :paro, :h_trab, :pacas, :h_paro, :obs
                        );
                    """), {
                        "fecha": id_fecha, "ts": ts, "maq": maquina_id,
                        "operador": dimensions.operator_id,
                        "producto": dimensions.product_id,
                        "paro": dimensions.stop_codes[codigo_paro],
                        "h_trab": h_trab, "pacas": pacas,
                        "h_paro": h_paro, "obs": obs
                    })
                registros_creados += 1
        
        print(f" 📅 [{id_fecha}] Registros cargados. Total acumulado: {registros_creados} filas.")
        fecha_actual += timedelta(days=1)
        time.sleep(0.2)  # Pausa de 0.2 segundos por día para ver la entrada progresiva

    print("\n✅ Carga de historial completada exitosamente.")

except KeyboardInterrupt:
    print("\n Carga cancelada por el usuario.")
