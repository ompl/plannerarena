import io
import pickle
import polars as pl
import plotnine as p9
from shiny import Inputs, Outputs, Session, module, reactive, render, ui, req
from widgets import (
    problem_widget,
    problem_parameter_filter,
    problem_parameter_values,
    problem_parameter_groups,
    problem_parameter_widgets,
    attribute_widget,
    version_widget,
    planner_widget,
    download_buttons,
    DataTuple
)


@module.ui
def regression_ui() -> ui.Tag:
    return ui.page_sidebar(
        ui.sidebar(
            ui.TagList(
                ui.output_ui("problem_ui"),
                ui.output_ui("problem_parameter_ui"),
                ui.output_ui("attribute_ui"),
                ui.output_ui("versions_ui"),
                ui.output_ui("planner_ui"),
            ),
            width="350px",
        ),
        download_buttons(),
        ui.output_plot("plot"),
    )


@module.server
def regression_server(
    input: Inputs, output: Outputs, session: Session, raw_data: reactive.Value
):
    @reactive.calc
    def exp_data() -> pl.DataFrame:
        return raw_data()["runs"].filter(pl.col("experiment") == input.problem())

    @reactive.calc
    def data() -> pl.DataFrame:
        param_values = problem_parameter_values(raw_data()["parameters"], input)
        grouping = problem_parameter_groups(param_values)
        df = problem_parameter_filter(exp_data().filter(
            (pl.col("version").is_in(input.versions()))
            & (pl.col("planner").is_in(input.planners()))
        ), param_values)
        if df["version"].unique().count()<=1:
            ui.notification_show("Need data for more than 1 version of OMPL", duration=5, type="warning")
            return pl.DataFrame({"version": [], "planner": [], input.attribute(): []})
        if grouping:
            # hacky way to create enum type from numerically sorted experiment parameters
            grouping_enum = pl.Enum(
                [str(v) for v in sorted(df[grouping].unique().to_list())]
            )
            df = df.with_columns(pl.col(grouping).cast(pl.String).cast(grouping_enum))
        return DataTuple(df, grouping)

    @output
    @render.ui
    def problem_ui() -> ui.Tag:
        return problem_widget(raw_data()["problem_names"])

    @output
    @render.ui
    def problem_parameter_ui() -> ui.Tag:
        return problem_parameter_widgets(
            raw_data()["experiments"].filter(
                (pl.col("experiment") == input.problem())
                & (pl.col("version").is_in(input.versions()))
            ),
            raw_data()["parameters"],
        )

    @output
    @render.ui
    def attribute_ui() -> ui.Tag:
        return attribute_widget(raw_data()["attributes"])

    @output
    @render.ui
    def versions_ui() -> ui.Tag:
        return version_widget(exp_data()["version"].unique().to_list(), checkbox=True)

    @output
    @render.ui
    def planner_ui():
        return planner_widget(exp_data()["planner"].unique().to_list())

    @reactive.calc
    def plot_object() -> p9.ggplot:
        req(len(data())>0)
        plot = (
            p9.ggplot(
                data().df, p9.aes(x="version", y=input.attribute(), fill="planner", group="planner")
            )
            + p9.stat_summary(geom="bar", position=p9.position_dodge(width=1))
            + p9.stat_summary(geom="errorbar", position=p9.position_dodge(width=1))
        )
        if data().grouping:
            plot = plot + p9.facet_grid(data().grouping)
        return plot

    @output
    @render.plot
    def plot():
        return plot_object()

    @render.download(filename="regression_plot.pdf")
    def download_pdf():
        buffer = io.BytesIO()
        plot_object().save(buffer, format="pdf")
        yield buffer.getvalue()

    @render.download(filename="regression_plot.pkl")
    def download_pkl():
        buffer = io.BytesIO()
        pickle.dump(plot_object(), buffer)
        yield buffer.getvalue()
