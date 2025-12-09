import os
from shiny import App, Inputs, Outputs, Session, reactive, ui
from shiny.types import FileInfo
import faicons as fa
from pathlib import Path
from plannerarena.database import database_info_ui, database_info_server, load_database
from plannerarena.performance import performance_ui, performance_server
from plannerarena.progress import progress_ui, progress_server
from plannerarena.regression import regression_ui, regression_server
import pandas as pd

pd.options.mode.copy_on_write = True

ASSET_DIR = Path(__file__).parent / "www"

# default database and max upload size are configurable via env vars
DATABASE = os.getenv("DATABASE", ASSET_DIR / "benchmark.db")
MAX_DB_SIZE = int(os.getenv("MAX_DB_SIZE", "50000000"))

app_ui = ui.page_navbar(
    ui.head_content(ui.include_css(ASSET_DIR / "plannerarena.css")),
    ui.nav_panel(
        "Overall performance",
        performance_ui("performance"),
        value="performance",
        icon=fa.icon_svg("chart-bar"),
    ),
    ui.nav_panel(
        "Progress",
        progress_ui("progress"),
        value="progress",
        icon=fa.icon_svg("chart-area"),
    ),
    ui.nav_panel(
        "Regression",
        regression_ui("regression"),
        value="regression",
        icon=fa.icon_svg("chart-bar"),
    ),
    ui.nav_panel(
        "Database info",
        database_info_ui("database_info"),
        value="database_info",
        icon=fa.icon_svg("circle-info"),
    ),
    ui.nav_panel(
        "Change database",
        ui.div(
            ui.div(
                ui.h2("Upload benchmark database"),
                ui.input_file(
                    "database",
                    label="",
                    accept=["application/x-sqlite3", ".db"],
                ),
                ui.h2("Default benchmark database"),
                ui.tags.ul(
                    ui.tags.li(
                        ui.a(
                            "Reset to default database", href="javascript:history.go(0)"
                        )
                    ),
                    ui.tags.li(ui.a("Download default database", href="benchmark.db")),
                ),
                class_="col-sm-10 offset-sm-1",
            ),
            class_="row",
        ),
        value="database",
        icon=fa.icon_svg("database"),
    ),
    ui.nav_panel(
        "Help",
        ui.div(
            ui.div(
                ui.markdown(open(ASSET_DIR / "help.md", "r").read()),
                class_="col-sm-10 offset-sm-1",
            ),
            class_="row",
        ),
        value="help",
        icon=fa.icon_svg("circle-question"),
    ),
    id="navbar",
    footer=ui.div(
        ui.div(
            "Created by ",
            ui.a("Mark Moll", href="https://moll.ai"),
            ui.HTML(" &bull; "),
            "Hosted by the ",
            ui.a("Kavraki Lab", href="https://kavrakilab.org"),
            " at ",
            ui.a("Rice University", href="https://www.rice.edu"),
            ui.HTML(" &bull; "),
            "Repository hosted on ",
            ui.a(
                ui.span(fa.icon_svg("github"), "GitHub"),
                href="https://github.com/ompl/plannerarena",
            ),
            ui.br(),
            "Funded in part by the ",
            ui.a("National Science Foundation", href="https://www.nsf.gov"),
            class_="container",
        ),
        ui.include_js(ASSET_DIR / "ga.js"),
        class_="footer",
    ),
    title="Planner Arena",
)


def app_server(input: Inputs, output: Outputs, session: Session):
    @reactive.calc
    def data():
        file: list[FileInfo] | None = input.database()
        if file is None or file[0]["size"] > MAX_DB_SIZE:
            if not Path(DATABASE).exists():
                ui.update_nav_panel("navbar", "database", "show")
                ui.update_navset("navbar", "database")
                ui.notification_show(
                "No default database found. Upload a database first.", duration=5, type="warning"
            )
            return load_database(DATABASE)
        return load_database(file[0]["datapath"])

    # after a new database is uploaded switch to the "performance" tab
    @reactive.effect
    @reactive.event(input.database)
    def _():
        ui.update_nav_panel("navbar", "performance", "show")
        ui.update_navset("navbar", "performance")

    # create all the different tabs
    performance_server("performance", data)
    progress_server("progress", data)
    regression_server("regression", data)
    database_info_server("database_info", data)

# create the Shiny app. The shiny command line app looks for this variable
app = App(app_ui, app_server, static_assets=ASSET_DIR)

def run():
    from shiny._main import run_app
    run_app(app, host="127.0.0.1", port=8888)
