import re
import sqlite3
import polars.selectors as cs
import polars as pl
from shiny import Inputs, Outputs, Session, module, reactive, render, ui


def get_table(conn: sqlite3.Connection, table: str) -> pl.DataFrame:
    df = pl.read_database(
        f"SELECT * from {table}", connection=conn, infer_schema_length=None
    )
    return df.rename({name: name.replace("_", " ") for name in df.columns})


def _version_key(version_string):
    # Split the version string into numerical and non-numerical parts
    # e.g., "1.2.3b" -> ['1', '.', '2', '.', '3', 'b']
    parts = re.split(r'(\d+)', version_string)
    # Convert numerical parts to integers, keep others as strings
    return tuple(int(p) if p.isdigit() else p for p in parts)

def load_database(dbname: str) -> dict:
    conn = sqlite3.connect(str(dbname))
    experiments = get_table(conn, "experiments").rename({"name": "experiment"})
    version_enum = pl.Enum(
            sorted(experiments['version'].unique().to_list(), key=_version_key)
        )
    experiments = experiments.with_columns(pl.col('version').cast(version_enum))
    problem_names = (
        experiments.get_column("experiment").unique(maintain_order=True).to_list()
    )

    planner_configs = (
        get_table(conn, "plannerConfigs")
        .rename({"name": "planner"})
        .with_columns(
            pl.col("planner")
            .str.replace("geometric_|control_", "")
            .cast(pl.Categorical)
        )
    )
    enums = get_table(conn, "enums").with_columns(
        pl.col("name").cast(pl.Categorical),
    )

    runs = get_table(conn, "runs")
    attributes = runs.columns[3:]

    exp_exclude_cols = [
        "totaltime",
        "timelimit",
        "memorylimit",
        "runcount",
        "hostname",
        "cpuinfo",
        "date",
        "seed",
        "setup",
    ]
    runs = runs.join(
        planner_configs.select("id", "planner"), left_on="plannerid", right_on="id"
    ).join(
        experiments.select(cs.exclude(exp_exclude_cols)),
        left_on="experimentid",
        right_on="id",
    )

    progress = get_table(conn, "progress")

    return {
        "experiments": experiments,
        "problem_names": problem_names,
        "parameters": experiments.columns[12:],
        "planner_configs": planner_configs,
        "enums": enums,
        "runs": runs,
        "attributes": attributes,
        "progress": progress,
    }


@module.ui
def database_info_ui():
    return ui.navset_tab(
        ui.nav_panel("Benchmark setup", ui.output_data_frame("benchmark_info")),
        ui.nav_panel("Planner Configuration", ui.output_data_frame("planner_configs")),
    )


@module.server
def database_info_server(
    input: Inputs, output: Outputs, session: Session, data: reactive.Value
):

    @output
    @render.data_frame
    def benchmark_info():
        return data()["experiments"].transpose(include_header=True)

    @output
    @render.data_frame
    def planner_configs():
        return data()["planner_configs"].select("planner", "settings").unique()
