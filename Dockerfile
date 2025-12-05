FROM ubuntu:24.04

ENV DATABASE=/plannerarena/www/benchmark.db
ENV MAX_DB_SIZE=50000000

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends gdebi-core python3-pip wget && \
    wget -nv https://download3.rstudio.org/ubuntu-20.04/x86_64/shiny-server-1.5.23.1030-amd64.deb && \
    gdebi -n shiny-server-1.5.23.1030-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* shiny-server-1.5.23.1030-amd64.deb
COPY plannerarena/ requirements.txt /plannerarena/
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
ADD --chown=shiny:shiny https://plannerarena.org/benchmark.db \
    /plannerarena/www/benchmark.db
WORKDIR /plannerarena
RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt && rm requirements.txt
EXPOSE 8888
RUN chown -R shiny:shiny /srv/shiny-server /var/lib/shiny-server
USER shiny
ENTRYPOINT [ "/usr/bin/shiny-server" ]
