Processes for `clutch up clutch.cw` (or `clutch serve`). Each heading under Processes is a
program to keep running; edit the fields after `>`.

# Environment

Given to every process:

> APP_ENV = development

# Processes

## web

Serves the site on port 8080 once the API is ready.

> command = python3 -m http.server 8080

> after = api

> ready = port 8080

> log = logs/web.log

## api

> shell = while true; do echo "api tick $APP_ENV $PORT"; sleep 5; done

> env.PORT = 9000

> restart = always

> log = logs/api.log

## migrate

Runs once at start; a successful exit is not restarted.

> command = echo migrated

> restart = on-failure
