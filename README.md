# Planner Arena

Planner Arena is a web app for interactively exploring benchmark databases created by the [Open Motion Planning Library (OMPL)](https://ompl.kavrakilab.org). A publicly accessible version of this code is running on <http://plannerarena.org>.

See `plannerarena/www/help.md` for details.

## Run directly from cloned repository

Run this code like so from this directory:

    pip3 install -r requirements.txt
    shiny run plannerarena/app.py

## Build/run docker image

Build a docker image and run it like so:

    docker build -t plannerarena:latest .
    docker run -p 8888:8888 plannerarena:latest

Planner Arena can then be accessed in your browser at <http://127.0.0.1:8888>.

## Build/run as a Python package

To build and install a Python package yourself, run:

    python3 -m build && pip3 install -U plannerarena-1.0-py3-none-any.whl

To download and install the version from PyPI, run:

    pip3 install -U plannerarena

Once `plannerarena` is installed, simply type `plannerarena` in the terminal and direct your browser to <http://127.0.0.1:8888>.
