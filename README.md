# Planner Arena

Planner Arena is a web app for interactively exploring OMPL benchmark databases. A publicly accessible version of this code is running on <http://plannerarena.org>.

See `plannerarena/www/help.md` for details.

Run this code like so from this directory:

    pip3 install -r requirements.txt
    shiny run plannerarena/app.py

Build a docker image and run it like so:

    docker build -t plannerarena:latest .
    docker run -p 8888:8888 plannerarena:latest

Planner Arena can then be accessed in your browser at <http://127.0.0.1:8888>.
