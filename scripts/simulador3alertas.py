import time
from datetime import date, datetime
from sqlalchemy import text
from db_connection import create_database_engine
from simulation_dimensions import ensure_simulation_dimensions

engine = create_database_engine()

today = date.today()

# Garantizar que la fecha exista en dim_tiempo
with engine.begin() as conn:
    dimensions = ensure_simulation_dimensions(conn)
    conn.execute(text("""
        INSERT INTO dim_tiempo (id_fecha, anio, mes, nombre_mes, dia, dia_semana, semana_anio)
        VALUES (:fecha, :anio, :mes, :nombre_mes, :dia, :dia_semana, :semana)
        ON CONFLICT (id_fecha) DO NOTHING;
    """), {
        "fecha": today, "anio": today.year, "mes": today.month,
        "nombre_mes": today.strftime('%B'), "dia": today.day,
        "dia_semana": today.strftime('%A'), "semana": today.isocalendar()[1]
    })

def insertar_evento(maquina_id, codigo_paro_id, h_trab, h_paro, pacas, obs):
    query = text("""
        INSERT INTO fact_paros_produccion (
            id_fecha, fecha_hora, id_maquina, id_operador, id_producto, 
            id_codigo_paro, horas_trabajadas, pacas_producidas, 
            horas_sin_trabajar, observacion
        ) VALUES (
            :fecha, :fecha_hora, :maq, :operador, :producto, :paro, :h_trab, :pacas, :h_paro, :obs
        );
    """)
    with engine.begin() as conn:
        conn.execute(query, {
            "fecha": today,
            "fecha_hora": datetime.now(),  # Marca la hora, minuto y segundo actual
            "maq": maquina_id,
            "operador": dimensions.operator_id,
            "producto": dimensions.product_id,
            "paro": codigo_paro_id,
            "h_trab": h_trab,
            "pacas": pacas,
            "h_paro": h_paro,
            "obs": obs
        })

print("="*65)
print(f"🚨 INICIANDO PRUEBA DE ALERTA EN TIEMPO REAL - {datetime.now().strftime('%H:%M:%S')}")
print("="*65)

try:
    print("\n🔴 INYECTANDO FALLA SEVERA EN TODAS LAS LÍNEAS (Disponibilidad < 30%)...")
    for i in range(6):
        now_str = datetime.now().strftime('%H:%M:%S')
        for maq in dimensions.machines.values():
            insertar_evento(
                maq,
                dimensions.stop_codes["[01]"],
                0.15,
                0.85,
                8,
                f"FALLA CRITICA REGISTRADA A LAS {now_str}",
            )
        print(f"   [!] {now_str} - Eventos de falla masiva insertados ({i+1}/6)")
        time.sleep(5)

    print("\n✅ Inyección de fallas completada. Revisa Grafana en los últimos 5 minutos.")

except KeyboardInterrupt:
    print("\n Simulador detenido.")
