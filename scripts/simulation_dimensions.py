from dataclasses import dataclass

from sqlalchemy import text
from sqlalchemy.engine import Connection


MACHINE_NAMES = ("Vinilos_1", "Vinilos_2", "Vinilos_3", "Vinilos_4")
STOP_CODES = ("[01]", "[02]", "[05]", "[14]", "[19]")
SIMULATION_OPERATOR = "SIMULACION - Operario"
SIMULATION_PRODUCT = "SIMULACION - Producto"


@dataclass(frozen=True)
class SimulationDimensions:
    machines: dict[str, int]
    operator_id: int
    product_id: int
    stop_codes: dict[str, int]


def ensure_simulation_dimensions(connection: Connection) -> SimulationDimensions:
    connection.execute(
        text(
            """
            INSERT INTO dim_operador (nombre_operador)
            VALUES (:name)
            ON CONFLICT (nombre_operador) DO NOTHING
            """
        ),
        {"name": SIMULATION_OPERATOR},
    )
    connection.execute(
        text(
            """
            INSERT INTO dim_producto (nombre_referencia)
            VALUES (:name)
            ON CONFLICT (nombre_referencia) DO NOTHING
            """
        ),
        {"name": SIMULATION_PRODUCT},
    )

    machines = dict(
        connection.execute(
            text(
                "SELECT nombre_maquina, id_maquina FROM dim_maquina "
                "WHERE nombre_maquina = ANY(:names)"
            ),
            {"names": list(MACHINE_NAMES)},
        ).all()
    )
    operators = dict(
        connection.execute(
            text(
                "SELECT nombre_operador, id_operador FROM dim_operador "
                "WHERE nombre_operador = :name"
            ),
            {"name": SIMULATION_OPERATOR},
        ).all()
    )
    products = dict(
        connection.execute(
            text(
                "SELECT nombre_referencia, id_producto FROM dim_producto "
                "WHERE nombre_referencia = :name"
            ),
            {"name": SIMULATION_PRODUCT},
        ).all()
    )
    stop_codes = dict(
        connection.execute(
            text(
                "SELECT codigo_oficial, id_codigo_paro FROM dim_codigo_paro "
                "WHERE codigo_oficial = ANY(:codes)"
            ),
            {"codes": list(STOP_CODES)},
        ).all()
    )

    missing_machines = set(MACHINE_NAMES) - machines.keys()
    missing_codes = set(STOP_CODES) - stop_codes.keys()
    if missing_machines or missing_codes:
        raise RuntimeError(
            "Faltan dimensiones requeridas para la simulación. "
            f"Máquinas: {sorted(missing_machines)}; códigos: {sorted(missing_codes)}. "
            "Ejecuta `docker compose up -d` para inicializar el esquema y los catálogos."
        )

    return SimulationDimensions(
        machines=machines,
        operator_id=operators[SIMULATION_OPERATOR],
        product_id=products[SIMULATION_PRODUCT],
        stop_codes=stop_codes,
    )
