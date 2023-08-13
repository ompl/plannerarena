FROM rocker/verse:4.3.1
RUN apt-get update -y && \
    apt-get install -y make zlib1g-dev git libicu-dev && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /usr/local/lib/R/etc/ /usr/lib/R/etc/ && \
    echo "options(renv.config.pak.enabled = TRUE, repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl', Ncpus = 8)" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site && \
    R -e 'install.packages(c("renv","remotes"))'
COPY renv.lock /
RUN R -e 'renv::restore()'
# run "R -e 'devtools::build(path=".")'" in this directory to create a distro tar ball in the parent directory.
COPY plannerarena_*.tar.gz /app.tar.gz
RUN R -e 'remotes::install_local("/app.tar.gz",upgrade="never")' && rm /app.tar.gz
# add a sample database
ADD https://www.cs.rice.edu/~mmoll/default-benchmark.db /benchmark.db
EXPOSE 80
ENV MAX_DB_SIZE=50000000
ENV HOSTNAME=0.0.0.0
ENV DATABASE=/benchmark.db
CMD R -e "options('shiny.port'=80,'shiny.host'='${HOSTNAME}','shiny.maxRequestSize'=${MAX_DB_SIZE},'plannerarena.default_database'='${DATABASE}');library(plannerarena);plannerarena::run_app()"
