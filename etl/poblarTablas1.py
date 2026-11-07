import hashlib
import os
from pathlib import Path

import pandas as pd
from sqlalchemy import URL, create_engine, text


excel_path = Path(
    os.getenv("EXCEL_FILE", "SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm")
)
if not excel_path.is_file():
    raise FileNotFoundError(f"No se encontró el archivo de entrada del ETL: {excel_path}")

file_hash = hashlib.sha256(excel_path.read_bytes()).hexdigest()
engine = create_engine(
    URL.create(
        "postgresql+psycopg2",
        username=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=int(os.getenv("POSTGRES_PORT", "5432")),
        database=os.getenv("POSTGRES_DB", "bi_envasado"),
    )
)

df = pd.read_excel(excel_path, sheet_name="Base De Datos", header=8)
df.columns = [str(column).strip() for column in df.columns]

with engine.connect() as connection:
    previous_import = connection.execute(
        text("SELECT source_sha256 FROM etl_imports WHERE source_name = :name"),
        {"name": excel_path.name},
    ).scalar_one_or_none()

    if previous_import == file_hash:
        print(f"ETL omitido: {excel_path.name} ya fue importado.")
        raise SystemExit(0)
    if previous_import is not None:
        raise RuntimeError(
            f"{excel_path.name} ya fue importado con otro contenido. "
            "Para recargarlo, reinicializa el volumen de PostgreSQL."
        )

    maquinas = pd.read_sql("SELECT id_maquina, nombre_maquina FROM dim_maquina", connection)
    operadores = pd.read_sql("SELECT id_operador, nombre_operador FROM dim_operador", connection)
    productos = pd.read_sql(
        "SELECT id_producto, nombre_referencia FROM dim_producto", connection
    )
    codigos_paro = pd.read_sql(
        "SELECT id_codigo_paro, codigo_oficial FROM dim_codigo_paro", connection
    )

dict_maq = dict(zip(maquinas["nombre_maquina"].str.strip(), maquinas["id_maquina"]))
dict_op = dict(zip(operadores["nombre_operador"].str.strip(), operadores["id_operador"]))
dict_prod = dict(zip(productos["nombre_referencia"].str.strip(), productos["id_producto"]))
dict_paro = dict(zip(codigos_paro["codigo_oficial"].str.strip(), codigos_paro["id_codigo_paro"]))

df["Fecha"] = pd.to_datetime(df["Fecha"], errors="coerce")
df["id_maquina"] = df["Maquina"].astype(str).str.strip().map(dict_maq)
df["id_operador"] = df["Operario"].astype(str).str.strip().map(dict_op)
df["id_producto"] = df["Referencia"].astype(str).str.strip().map(dict_prod)
df["codigo_extraido"] = df["Tipo de paro"].astype(str).str.extract(r"(\[\d+\])")[0]
df["id_codigo_paro"] = df["codigo_extraido"].map(dict_paro)
df["pacas_producidas"] = pd.to_numeric(df["Pacas producidas"], errors="coerce").fillna(0)
df["horas_trabajadas"] = pd.to_numeric(df["Horas trabajadas"], errors="coerce").fillna(0)
df["horas_sin_trabajar"] = pd.to_numeric(
    df["Horas no trabajadas"], errors="coerce"
).fillna(0)
df = df.dropna(subset=["Fecha", "id_maquina"]).copy()

df_to_insert = pd.DataFrame(
    {
        "id_fecha": df["Fecha"].dt.date,
        "fecha_hora": df["Fecha"],
        "id_maquina": df["id_maquina"].astype("Int64"),
        "id_operador": df["id_operador"].astype("Int64"),
        "id_producto": df["id_producto"].astype("Int64"),
        "id_codigo_paro": df["id_codigo_paro"].astype("Int64"),
        "horas_trabajadas": df["horas_trabajadas"],
        "pacas_producidas": df["pacas_producidas"],
        "horas_sin_trabajar": df["horas_sin_trabajar"],
        "observacion": df["Observaciones de paro"].fillna("").astype(str),
    }
)

with engine.begin() as connection:
    df_to_insert.to_sql(
        "fact_paros_produccion",
        connection,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1000,
    )
    connection.execute(
        text(
            """
            INSERT INTO etl_imports (source_name, source_sha256, imported_rows)
            VALUES (:name, :file_hash, :row_count)
            """
        ),
        {
            "name": excel_path.name,
            "file_hash": file_hash,
            "row_count": len(df_to_insert),
        },
    )

print(
    f"ETL completado: se cargaron {len(df_to_insert)} registros "
    "en fact_paros_produccion."
)
