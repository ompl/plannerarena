# Planner Arena

[Planner Arena](https://plannerarena.org) is a site for benchmarking sampling-based planners. The site is set up to show the performance of implementations of various sampling-based planning algorithms in the [Open Motion Planning Library (OMPL)](https://ompl.kavrakilab.org).

## Running Planner Arena locally

### Docker

If you are familiar with Docker, then the easiest way to run Planner Arena locally is to run the same docker container we use for our web server:

    docker pull kavrakilab/plannerarena:latest
    docker run --rm -p 8888:8888 kavrakilab/plannerarena:latest

Direct your browser to http://0.0.0.0:8888 to see Planner Arena. There are a couple environment variables to configure Planner Arena by running `docker run -e VARIABLE=VALUE ...`:

- `DATABASE` (default value: `/benchmark.db`): The file name of the default benchmark database (inside the docker container). By mounting a host file inside the container, you can make a local benchmark database the default. For example:

      docker run --rm -p 8888:8888 --mount type=bind,source=${HOME}/mybenchmark.db,target=/tmp/benchmark.db,readonly -e DATABASE=/tmp/benchmark.db kavrakilab/plannerarena:latest

- `MAX_DB_SIZE` (default value: `50000000`): The maximum size in bytes of the database that can be uploaded to the server.
- `HOSTNAME` (default value: `0.0.0.0`): The IP address of the host.

If you have cloned this repository and would like to make a custom docker image, type the following commands in the top-level directory of this repository:

    R -e 'devtools::build(path=".")'
    docker build -t plannerarena:latest .

### R

If you are somewhat familiar with R, you can install Planner Arena like so:

    R -e 'install.packages("remotes", repos="https://cran.r-project.org"); remotes::install_github("ompl/plannerarena")'

If installation was successful, you can run Planner Arena like so:

    R -e "plannerarena::run_app()"

This slightly more complex version of starting Planner Arena enables you to pass in arguments via environment variables as is done for the Docker version:

    R -e "options('shiny.port'=80,'shiny.host'='${HOSTNAME}','shiny.maxRequestSize'=${MAX_DB_SIZE},'plannerarena.default_database'='${DATABASE}');library(plannerarena);plannerarena::run_app()"
