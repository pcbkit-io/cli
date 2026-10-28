# pcbkit for agents

`pcbkit` is a local command line for printed circuit boards: it checks, places, routes, fills,
renders and exports a board that lives in a folder on this computer (a KiCad project; Altium,
Eagle and EasyEDA boards are imported into one). Install: `curl -fsSL https://pcbkit.io/install.sh | sh`
(Windows: `irm https://pcbkit.io/install.ps1 | iex`). `pcbkit --version` says which you have.

## The contract

- **One JSON document on stdout** for every command (nothing else is printed there; progress and
  logs go to stderr). Read it, do not scrape text.
- Fields: `ok` (the command ran), `status` (the board's check after it: `complete`,
  `incomplete` = connections missing, `error` = the check finds errors), `summary` (one sentence
  for a person, ending with `Next: …` = the usual next command), `result` (the command's own
  answer), `written` (files changed), `outputs` (files exported), `error` when `ok` is false
  (`code`: `invalid_input`, `invalid_state`, `not_found`, `failed`, …; `message` says what to do).
- **Exit codes:** `0` fine; `1` problems found (the check finds errors, routing left connections
  missing, parts unresolved, the command refused); `2` could not run (bad arguments, unreadable
  files). Exit 1 is an answer, not a crash: read `summary`.
- `-C DIR` runs on the project in `DIR` (default: the current directory).

## Discover

```sh
pcbkit --help                       # the subcommands
pcbkit commands                     # every registry command: name, description, annotations, JSON Schemas of input and result
pcbkit commands --markdown          # the same as a readable catalogue
pcbkit docs --out /tmp/pcbkit-docs  # agents.md, llms.txt, llms-full.txt: the guide, the catalogue, the PCBKit language, the board format
```

The subcommands (`check`, `route`, `export`, …) are shortcuts for registry commands;
`pcbkit call NAME 'JSON'` runs any of them (`-` reads the JSON from stdin), e.g.

```sh
pcbkit call board.get '{"ids": ["U1", "net:GND"]}'
pcbkit call design.check '{"severity": "error", "limit": 20}'
pcbkit call board.move '{"id": "J1", "at": [2, 15]}'
pcbkit call project.summary '{"stats": true}'
```

Changed files are written back into the project; jobs (routing, exports) run to the end before
the answer; exports go to `--out`.

## A KiCad project

```sh
cd board/ && git status             # commit first: every change is then a diff
pcbkit init                         # adds .pcbkit/ (design.pcbkit, FORMAT.md), AGENTS.md, a check hook; the .kicad_pcb stays the board
pcbkit check                        # what is wrong, with ids (`R1`, `net:VBUS`, `pad:U1.3`) and positions
pcbkit route                        # routes unrouted nets, refills pours; placed parts do not move
pcbkit check
pcbkit render --out top.png         # look at it (2D); --3d, --parts, --light
pcbkit export --format fab          # fabrication/: Gerber, drill, BOM, placement (needs check `complete`, or --force)
```

- Do not edit the `.kicad_pcb` while KiCad has it open with unsaved changes: KiCad would overwrite
  what `pcbkit` wrote (and the other way round). Reopen it in KiCad after `route`.
- `pcbkit route --all` places and routes everything anew: only when asked.
- Formats in: KiCad 4–10, Altium `.PcbDoc`, Eagle `.brd`, EasyEDA Standard `.json` and Pro
  `.epro`, Specctra `.ses` (another router's result). Out: KiCad, Gerber/drill/BOM/placement,
  IPC-2581C, Specctra `.dsn`, schematic SVG/PDF, PNG, JSON.

## A new board from words

`pcbkit init` in an empty folder starts a project whose design is `.pcbkit/design.pcbkit`, written
in the PCBKit language (nets, parts, blocks, connections, no coordinates). The guide that `init`
writes (`AGENTS.md` in the project) and `pcbkit docs` explain the language and the blocks;
`pcbkit route` places, routes and writes the KiCad board.

## Agents over MCP

`pcbkit mcp` serves the project's commands as MCP tools on stdin/stdout (`--http 127.0.0.1:8787`
for streamable HTTP at `/mcp`). The [PCBKit plugin](https://github.com/pcbkit-io/plugins) for Claude
Code and Codex starts it for you.

## Network

Offline: everything except `pcbkit parts` (orderable parts from PCBKit's catalogue), the hosted 3D
models (`render --3d --models`) and the hosted footprint library in `pcbkit footprints`. Nothing is
sent anywhere by the other commands.
