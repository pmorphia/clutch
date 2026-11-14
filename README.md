# Clutch

A process manager for [Flywheel](https://flywheel.polymorphia.dev). Clutch starts a set of
programs in dependency order, waits until each is ready, restarts the ones that stop, and
lets you control them while they run.

```sh
pulley add polymorphia.clutch
```

```flywheel
import clutch

var c = clutch.Clutch()
c.env("APP_ENV", "production")                          # for every process
c.add("db", ["redis-server", "--port", "6380"]).ready_port(6380)
c.add("api", ["flywheel", "api.fw"]).after("db").env("PORT", "9000").log("logs/api.log")
c.add("worker", ["flywheel", "worker.fw"]).after("db").restart("always")
c.shell("assets", "npm run watch | tee logs/assets.log")
c.up()          # start everything, supervise it, and stop it all when supervision ends
```

Clutch needs a Flywheel compiler newer than 2.17, which has `os.start`, `os.alive`,
`os.kill`, and `os.wait` for background processes.

## Processes

`c.add(name, command)` adds a program (`c.shell(name, line)` runs a line with `/bin/sh -c`).
Each method returns the `clutch.Process`, so settings chain:

| | |
|---|---|
| `after(name)` | start after that process (and stop before it); cycles are an error |
| `env(name, value)`, `cwd(path)` | its environment and working directory |
| `log(path)` | append its output to a file (directories are created); otherwise it shares the manager's output |
| `restart(policy)` | `"on-failure"` (the default: when it exits with a nonzero status), `"always"`, or `"never"` |
| `give_up_after(n)` | stop restarting after `n` restarts in a row (default 10; 0 never gives up) |
| `ready_port(port, timeout = "30s")` | it is ready once something listens on that port of 127.0.0.1 |
| `ready_file(path, timeout)`, `ready_after(delay)` | ready once a file exists, or after a delay |
| `stop_grace(duration)` | how long to wait after SIGTERM before SIGKILL (default 5s) |
| `manual()` | not started by `start_all` / `up` |

Processes that need another one start only once it is ready. Every process gets
`CLUTCH_PROCESS` (its own name) and `CLUTCH_PID_<NAME>` for each process already running, so
programs can find each other. A process that exits soon after starting is restarted after 1s,
then 2s, 4s, and so on up to 30s; after it has run for 30s the wait starts again at 1s.

A process's `state` is `stopped`, `starting`, `running`, `exited`, `backoff` (waiting to
restart), or `failed`, with its `pid`, `exit_status`, `restarts`, `uptime()`, and `message`.
`c.on_change = function(clutch.Process p, string state) ... end` is called on every change.

## Running

| | |
|---|---|
| `c.up()` | `start_all()`, `supervise()`, then `stop_all()` |
| `c.start(name)`, `c.stop(name)`, `c.restart_process(name)` | one process (with what it needs, or what needs it) |
| `c.start_all()`, `c.stop_all()` | everything, in dependency order |
| `c.supervise()` | check the processes every `c.interval` seconds until `c.shutdown()` or nothing is left running |
| `c.check()` | one round of that, for your own loop |
| `c.status()` | a table |
| `c.serve(port = 7979, host = "127.0.0.1")` | `start_all()`, supervise on a background thread, and answer control requests |

Managed programs stay in the manager's process group, so a Ctrl-C in the terminal stops them
together with Clutch.

### Control requests

While `c.serve(port)` runs, the processes can be controlled over HTTP:

| Request | Does |
|---|---|
| `GET /status`, `GET /status/:name` | the processes, as JSON |
| `POST /start/:name`, `/stop/:name`, `/restart/:name` | change one |
| `GET /logs/:name?lines=N` | the end of its log file |
| `POST /shutdown` | stop everything and exit |

`clutch.client(port)` talks to it from another program: `status()`, `start(name)`,
`stop(name)`, `restart(name)`, `logs(name, lines)`, and `shutdown()`.

## Process files

The processes can be written in a [Cogwheel](https://github.com/pmorphia/cogwheel) file
([clutch.cw](clutch.cw)), which is Markdown, so it documents itself:

```markdown
# Environment

> APP_ENV = development

# Processes

## api

Serves the API on port 9000.

> command = flywheel api.fw

> after = db

> ready = port 9000

> env.PORT = 9000

> restart = always

> log = logs/api.log
```

Each section under `# Processes` is a process named by its heading: a `command` (split into
arguments; quotes group them) or a `shell` line, and optionally `cwd`, `log`, `restart`,
`after` (comma-separated), `ready` (`port 9000`, `file PATH`, `delay 2s`), `ready timeout`,
`grace`, `max restarts`, `autostart`, and `env.NAME` entries. The entries of `# Environment`
go to every process. `clutch.from_file(path)` reads one into a `Clutch`, and
`clutch.load(c, document)` adds a document's processes to yours.

The `clutch` command comes with the package: `pulley install polymorphia.clutch` puts it on your
`PATH`, and in a project that depends on Clutch, `pulley run clutch ...` runs it (as do the
project's `[scripts]`).

```sh
clutch up clutch.cw        # here, until Ctrl-C
clutch serve clutch.cw     # with control requests on port 7979
clutch status              # from another terminal
clutch restart api
clutch logs api
clutch shutdown
clutch check clutch.cw     # print the start order
```

## Development

```sh
flywheel --test tests/
```

MIT license.
