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
def performance_ui() -> ui.Tag:
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
                            "show_as_cdf", "Show as cumulative distribution function"
                        ),
                        ui.input_checkbox(
                            "show_simplified", "Include results after simplification"
                        ),
                        ui.input_checkbox(
                            "hide_outliers", "Hide outliers in box plots"
                        ),
                        ui.input_checkbox("y_log_scale", "Use log scale for Y-axis"),
                    ),
                ),
                ui.output_ui("version_ui"),
                ui.output_ui("planner_ui"),
            ),
            width="350px",
        ),
        ui.HTML(
            """<div class="alert alert-info alert-dismissible fade show" role="alert">
<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
If you use Planner Arena or the OMPL benchmarking facilities, then we kindly ask you to include the following citation in your publications:
<blockquote>
   Mark Moll, Ioan A. Șucan, Lydia E. Kavraki, <a href=\"https://moll.ai/publications/moll2015benchmarking-motion-planning-algorithms.pdf\">Benchmarking Motion Planning Algorithms: An Extensible Infrastructure for Analysis and Visualization</a>, <em>IEEE Robotics & Automation Magazine,</em> 22(3):96–102, September 2015. doi: <a href=\"https://dx.doi.org/10.1109/MRA.2015.2448276\">10.1109/MRA.2015.2448276</a>.
 </blockquote>
</div>"""
        ),
        download_buttons(),
        ui.output_plot("plot"),
        ui.output_data_frame("missing_data_table"),
    )


def enums_plot(df: pl.DataFrame, enum: pl.DataFrame, grouping: str) -> p9.ggplot:
    """Create a stacked bar chart for enum types (e.g., "status").

    If grouping is not empty, facetting is used (one plot per group variable value)
    """
    df = df.join(enum, left_on="status", right_on="value")
    plot = p9.ggplot(df, p9.aes(x="planner", fill="description")) + p9.geom_bar()
    if grouping:
        return plot + p9.facet_grid(grouping)
    else:
        return plot


def ecdf_plot(df: pl.DataFrame, attr: str, grouping: str) -> p9.ggplot:
    """Create a plot of the empirical cumulative distribution function for the specified attribute."""
    plot = (
        p9.ggplot(df, p9.aes(x=attr, color="planner"))
        + p9.xlab(attr)
        + p9.ylab("cumulative probability")
        + p9.stat_ecdf()
    )
    if grouping:
        return plot + p9.scale_linetype(name=grouping)
    else:
        return plot


def ecdf_plot_with_simplified(df: pl.DataFrame, attr: str) -> p9.ggplot:
    """Create a plot of the empirical cumulative distribution function for the specified attribute
    and the value of the attribute after path simplification."""
    return (
        p9.ggplot(
            df.with_columns(
                pl.col("planner").cast(pl.Utf8).alias("plannerstr"),
                pl.col("key").cast(pl.Utf8).alias("keystr"),
            ),
            p9.aes(
                x="value",
                color="planner",
                group="plannerstr+'.'+keystr",
                linetype="key",
            ),
        )
        + p9.xlab(attr)
        + p9.ylab("cumulative probability")
        + p9.stat_ecdf()
        + p9.scale_linetype_discrete(
            name=" ",
            labels=["before simplification", "after simplification"],
        )
    )


def boxplot(
    df: pl.DataFrame, attr: str, grouping: str, outlier_shape: str, ylogscale: bool
) -> p9.ggplot:
    """Create a box plot for the specified attribute for each selected planner."""

    if grouping:
        plot = p9.ggplot(
            df, p9.aes(x="planner", y=attr, fill=grouping)
        ) + p9.geom_boxplot(
            position=p9.position_dodge2(width=0.8), outlier_shape=outlier_shape
        )
    else:
        plot = p9.ggplot(df, p9.aes(x="planner", y=attr)) + p9.geom_boxplot(
            color="#3073ba", fill="#99c9eb", outlier_shape=outlier_shape
        )
    if ylogscale:
        return plot + p9.scale_y_log10()
    else:
        return plot


def boxplot_with_simplified(
    df: pl.DataFrame, attr: str, outlier_shape: str, ylogscale: bool
) -> p9.ggplot:
    """Create a box plot for the specified attribute and the value of the attribute after path
    simplification for each selected planner."""
    plot = (
        p9.ggplot(df, p9.aes(x="planner", y="value", color="key", fill="key"))
        + p9.ylab(attr)
        + p9.geom_boxplot(outlier_shape=outlier_shape)
        + p9.scale_fill_manual(
            ["#99c9eb", "#ebc999"],
            name=" ",
            labels=["before simplification", "after simplification"],
        )
        + p9.scale_color_manual(
            ["#3073ba", "#ba7330"],
            name=" ",
            labels=["before simplification", "after simplification"],
            na_value="#7F7F7F",
        )
    )
    if ylogscale:
        return plot + p9.scale_y_log10()
    else:
        return plot


@module.server
def performance_server(
    input: Inputs, output: Outputs, session: Session, raw_data: reactive.Value
):
    @reactive.calc
    def exp_data() -> pl.DataFrame:
        """Return data for the selected experiment"""
        req(not raw_data()["runs"].is_empty())
        return raw_data()["runs"].filter(pl.col("experiment") == input.problem())

    @reactive.calc
    def data() -> DataTuple:
        """Return data for the selected OMPL version, the selected planners, and selected experiment
        parameters (if present)"""
        param_values = problem_parameter_values(raw_data()["parameters"], input)
        grouping = problem_parameter_groups(param_values)
        df = problem_parameter_filter(
            exp_data().filter(
                (pl.col("version") == input.version())
                & (pl.col("planner").is_in(input.planners()))
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
        req(raw_data()["attributes"])
        return attribute_widget(raw_data()["attributes"])

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
        attr = input.attribute()
        # use bar charts for enum types
        enums = raw_data()["enums"].filter(pl.col("name") == attr)
        grouping = data().grouping
        if len(enums) > 0:
            return enums_plot(data().df, enums, grouping)

        outlier_shape = "" if input.hide_outliers() else "o"
        simplified_attr = "simplified " + attr
        include_simplified_attr = (
            input.show_simplified() and simplified_attr in raw_data()["attributes"]
        )

        if include_simplified_attr:
            df = (
                data()
                .df.unpivot(
                    index=["planner"],
                    on=[attr, simplified_attr],
                    variable_name="key",
                    value_name="value",
                )
                .with_columns(pl.col("key").cast(pl.Categorical))
            )
            if input.show_as_cdf():
                return ecdf_plot_with_simplified(df, attr)
            return boxplot_with_simplified(df, attr, outlier_shape, input.y_log_scale())
        else:
            df = data().df
            if input.show_as_cdf():
                return ecdf_plot(df, attr, grouping)

            return boxplot(df, attr, grouping, outlier_shape, input.y_log_scale())

    @output
    @render.plot
    def plot():
        return plot_object()

    @render.download(filename="performance_plot.pdf")
    def download_pdf():
        buffer = io.BytesIO()
        plot_object().save(buffer, format="pdf")
        yield buffer.getvalue()

    @render.download(filename="performance_plot.pkl")
    def download_pkl():
        buffer = io.BytesIO()
        pickle.dump(plot_object(), buffer)
        yield buffer.getvalue()

    @output
    @render.data_frame
    def missing_data_table():
        req(input.attribute)
        grouping = data().grouping
        if grouping:
            grouping = ["planner", grouping]
        else:
            grouping = ["planner"]
        return (
            data()
            .df.with_columns(pl.col(input.attribute()).is_null().alias("missing"))
            .group_by(grouping)
            .agg(pl.col("missing").sum(), pl.len().alias("total"))
            .sort(grouping)
        )
