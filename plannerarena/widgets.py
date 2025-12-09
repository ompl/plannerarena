from collections import namedtuple
from shiny import ui, Inputs
import polars as pl
import faicons as fa

PROBLEM_PARAMETERS_AGGREGATE_TEXT = "all (aggregate)"
PROBLEM_PARAMETERS_SEPARATE_TEXT = "all (separate)"

DataTuple = namedtuple("DataTuple", ["df", "grouping"])


def problem_widget(problems: list[str]) -> ui.Tag:
    return ui.input_select(
        "problem", label=ui.h4("Motion planning problem"), choices=problems
    )


def _problem_parameter_id_map(parameters: list[str]) -> dict[str, str]:
    return {
        parameter: "problem_param" + parameter.replace(" ", "_")
        for parameter in parameters
    }


def problem_parameter_filter(df: pl.DataFrame, param_values: dict[str, str]):
    for param, value in param_values.items():
        if (
            value != PROBLEM_PARAMETERS_AGGREGATE_TEXT
            and value != PROBLEM_PARAMETERS_SEPARATE_TEXT
        ):
            try:
                val = float(value)
                df = df.filter(pl.col(param).is_close(val, abs_tol=1e-7, rel_tol=1e-7))
            except ValueError:
                df = df.filter(pl.col(param) == value)
    return df


def problem_parameter_values(parameters: list[str], input: Inputs) -> dict[str, str]:
    return {
        param: input[param_id].get()
        for param, param_id in _problem_parameter_id_map(parameters).items()
        if input[param_id].is_set()
    }


def problem_parameter_groups(param_values: dict[str, str]) -> str:
    for param, val in param_values.items():
        if val == PROBLEM_PARAMETERS_SEPARATE_TEXT:
            return param
    return []


def problem_parameter_widget(
    data: pl.DataFrame, param_id: str, parameter: str
) -> ui.Tag:
    values = data[parameter].unique().drop_nulls().to_list()
    if len(values) > 1:
        values = [
            PROBLEM_PARAMETERS_AGGREGATE_TEXT,
            PROBLEM_PARAMETERS_SEPARATE_TEXT,
        ] + values
    return ui.input_select(
        param_id,
        label=ui.h6(parameter),
        choices=values,
    )


def problem_parameter_widgets(
    data: pl.DataFrame, parameters: list[str]
) -> ui.Tag | None:
    if len(parameters) > 0:
        return ui.card(
            ui.h5("Problem parameters"),
            [
                problem_parameter_widget(data, id, param)
                for param, id in _problem_parameter_id_map(parameters).items()
            ],
        )
    return None


def attribute_widget(
    attributes: list[str], label: str = "Benchmark attribute"
) -> ui.Tag:
    return ui.input_select(
        "attribute",
        label=ui.h4(label),
        choices=attributes,
        selected="time" if "time" in attributes else None,
    )


def version_widget(versions: list[str], checkbox: bool = False) -> ui.Tag | None:
    if not versions:
        return None
    if checkbox:
        return ui.input_checkbox_group(
            "versions",
            label=ui.h4("Selected versions"),
            choices=versions,
            selected=versions,
        )
    else:
        return ui.input_select(
            "version",
            label=ui.h4("Version"),
            choices=versions,
            selected=versions[-1],
        )


def planner_widget(planners: list[str]) -> ui.Tag:
    # select first 4 planners (or all if there are less than 4)
    return ui.input_checkbox_group(
        "planners",
        label=ui.h4("Selected planners"),
        choices=planners,
        selected=planners[: min(len(planners), 4)],
    )


def download_buttons() -> ui.Tag:
    return ui.div(
        ui.download_button(
            "download_pdf",
            "Download plot as PDF",
            icon=fa.icon_svg("download"),
            class_="btn-outline-primary",
        ),
        ui.download_button(
            "download_pkl",
            "Download plot as Python pickle file",
            icon=fa.icon_svg("download"),
            class_="btn-outline-primary",
        ),
        class_="btn-group",
    )
