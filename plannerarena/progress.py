import io
import pickle
import polars as pl
import plotnine as p9
from shiny import Inputs, Outputs, Session, module, reactive, render, ui, req
from plannerarena.widgets import (
    problem_widget,
    problem_parameter_filter,
    problem_parameter_values,
    problem_parameter_groups,
    problem_parameter_widgets,
    attribute_widget,
    version_widget,
    planner_widget,
    download_buttons,
    DataTuple,
)


@module.ui
def progress_ui() -> ui.Tag:
    return ui.page_sidebar(
        ui.sidebar(
            ui.TagList(
                ui.output_ui("problem_ui"),
                ui.output_ui("problem_parameter_ui"),
                ui.output_ui("attribute_ui"),
                ui.input_checkbox("advanced_options", "Show advanced options"),
                ui.panel_conditional(
                    "input.advanced_options",
                    ui.card(
                        ui.input_checkbox(
                            "show_measurements", "Show individual measurements"
                        ),
                        ui.input_slider("opacity", "Measurement opacity", 0, 100, 50),
                    ),
                ),
                ui.output_ui("version_ui"),
                ui.output_ui("planner_ui"),
            ),
            width="350px",
        ),
        download_buttons(),
        ui.output_plot("plot"),
        ui.output_plot("plot_num_measurements"),
    )


@module.server
def progress_server(
    input: Inputs, output: Outputs, session: Session, raw_data: reactive.Value
):
    @reactive.calc
    def exp_data() -> pl.DataFrame:
        req(not raw_data()["runs"].is_empty())
        return raw_data()["runs"].filter(pl.col("experiment") == input.problem())

    @reactive.calc
    def data() -> DataTuple:
        req(not raw_data()["progress"].is_empty())
        param_values = problem_parameter_values(raw_data()["parameters"], input)
        grouping = problem_parameter_groups(param_values)
        df = problem_parameter_filter(
            raw_data()["progress"].join(
                exp_data()
                .filter(
                    (pl.col("version") == input.version())
                    & (pl.col("planner").is_in(input.planners()))
                )
                .select(["id", "planner", grouping]),
                left_on="runid",
                right_on="id",
            ),
            param_values,
        )
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
        req(raw_data()["problem_names"])
        return problem_widget(raw_data()["problem_names"])

    @output
    @render.ui
    def problem_parameter_ui() -> ui.Tag | None:
        req(not raw_data()["experiments"].is_empty())
        return problem_parameter_widgets(
            raw_data()["experiments"].filter(
                (pl.col("experiment") == input.problem())
                & (pl.col("version") == input.version())
            ),
            raw_data()["parameters"],
        )

    @output
    @render.ui
    def attribute_ui() -> ui.Tag:
        req(not raw_data()["progress"].is_empty())
        return attribute_widget(
            raw_data()["progress"].columns[2:], "Progress attribute"
        )

    @output
    @render.ui
    def version_ui() -> ui.Tag | None:
        return version_widget(exp_data()["version"].unique().to_list())

    @output
    @render.ui
    def planner_ui() -> ui.Tag:
        return planner_widget(exp_data()["planner"].unique().to_list())

    @reactive.calc
    def plot_object() -> p9.ggplot:
        req(not data().df.is_empty())
        plot = (
            p9.ggplot(
                data().df,
                p9.aes(
                    x="time",
                    y=input.attribute(),
                    color="planner",
                    fill="planner",
                ),
            )
            + p9.xlab("time (s)")
            # TODO: make this work with statsmodels' GAM
            + p9.geom_smooth(na_rm=True, method="loess", span=0.1, se=False)
        )
        if data().grouping:
            plot = plot + p9.scale_linetype(name=data().grouping)
        if input.show_measurements():
            plot = plot + p9.geom_point(alpha=input.opacity() / 100)
        return plot

    @reactive.calc
    def plot_num_measurements_object() -> p9.ggplot:
        req(not data().df.is_empty())
        plot = (
            p9.ggplot(data().df, p9.aes(x="time", color="planner"))
            + p9.xlab("time (s)")
            + p9.ylab(f"# measurements for {input.attribute()}")
            + p9.geom_freqpoly(binwidth=1)
        )
        if data().grouping:
            plot = plot + p9.scale_linetype(name=data().grouping)
        return plot

    @output
    @render.plot
    def plot():
        return plot_object()

    @output
    @render.plot
    def plot_num_measurements():
        return plot_num_measurements_object()

    @render.download(filename="progress_plot.pdf")
    def download_pdf():
        buffer = io.BytesIO()
        (plot_object() / plot_num_measurements_object()).save(buffer, format="pdf")
        yield buffer.getvalue()

    @render.download(filename="progress_plot.pkl")
    def download_pkl():
        buffer = io.BytesIO()
        pickle.dump([plot_object(), plot_num_measurements_object()], buffer)
        yield buffer.getvalue()
