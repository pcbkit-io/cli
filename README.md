# pcbkit — the PCBKit command line

`pcbkit` routes, checks, renders and exports printed circuit boards on your own computer: KiCad
projects as they are, and Altium, Eagle and EasyEDA boards imported into KiCad. One binary, no
account, works offline; every command answers in JSON, so scripts, CI and agents drive it as
easily as people do.

It is the engine of [PCBKit](https://pcbkit.io): the same router, checks, renderer and exporters
that run in the web app and in the PCBKit plugins for Claude, ChatGPT and Codex. PCBKit is free.

## Install

macOS and Linux:

```sh
curl -fsSL https://pcbkit.io/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://pcbkit.io/install.ps1 | iex
```

Homebrew (macOS, Linux):

```sh
brew install pcbkit-io/tap/pcbkit
```

The script downloads the release for your system from
[GitHub Releases](https://github.com/pcbkit-io/cli/releases), checks its SHA-256 and installs
`pcbkit` into `~/.local/bin` (its notices in `~/.local/share/pcbkit`; Windows:
`%LOCALAPPDATA%\Programs\pcbkit`). `PCBKIT_VERSION=2026.10.28` installs that version,
`PCBKIT_PREFIX=/usr/local` another place. Run it again to update.

| System | Archive |
|---|---|
| macOS, Apple silicon | `pcbkit-aarch64-apple-darwin.tar.gz` |
| macOS, Intel | `pcbkit-x86_64-apple-darwin.tar.gz` |
| Linux x86_64 (glibc 2.35+: Ubuntu 22.04, Debian 12, Fedora 36 and newer) | `pcbkit-x86_64-unknown-linux-gnu.tar.gz` |
| Linux arm64 (glibc 2.35+) | `pcbkit-aarch64-unknown-linux-gnu.tar.gz` |
| Windows x86_64 | `pcbkit-x86_64-pc-windows-msvc.zip` |

The binaries are not signed yet. The script and Homebrew need nothing more; an archive downloaded
with a browser on macOS needs `xattr -d com.apple.quarantine bin/pcbkit` once.

Pictures (`pcbkit render`) need a GPU or a software renderer: macOS and Windows have one; on a
Linux machine without a GPU install Mesa's (`apt install mesa-vulkan-drivers`, `dnf install
mesa-vulkan-drivers`).

## Quickstart on a KiCad project

```sh
cd my-board/                  # a folder with a .kicad_pcb (and its .kicad_pro, schematic)
pcbkit init                   # makes it a PCBKit project: adds .pcbkit/, AGENTS.md; the board stays yours
pcbkit check                  # errors, warnings and unrouted nets, as KiCad's rules and the fab's limits say
pcbkit route                  # routes what is unrouted and refills the pours, written into the .kicad_pcb
pcbkit render --out top.png   # a picture of the board; --3d for the assembled board
pcbkit export --format fab    # Gerber, drill, BOM and placement files for the fab, in fabrication/
```

Open the board in KiCad at any time: `pcbkit` writes the KiCad file itself, and parts you placed
stay where they are (`route` moves nothing that is placed). Commit before you route, and `git diff`
shows what changed.

Another tool's board:

```sh
pcbkit import board.PcbDoc    # Altium; also Eagle .brd, EasyEDA .json / .epro, KiCad 4–10
cd board && pcbkit route
```

## What it does

| Command | What |
|---|---|
| `pcbkit init`, `pcbkit import FILE` | a project from a KiCad folder; a board from Altium (`.PcbDoc`), Eagle (`.brd`), EasyEDA (Standard `.json`, Pro `.epro`), KiCad 4–10, a Specctra session (`.ses`) |
| `pcbkit route`, `place`, `fill` | the router (multi-layer, the board's own rules and net classes, differential pairs), the placer for parts without a position, pour fills as KiCad fills them |
| `pcbkit check` | electrical and design rules, clearances, the fab's limits, unrouted nets (`--severity`, `--code`, pages) |
| `pcbkit render` | PNG of the board in 2D or 3D (`--3d`, `--parts`, `--light`), the schematic as SVG or PDF (`--schematic`), frame sequences |
| `pcbkit export --format …` | `fab` (Gerber, drill, BOM, placement: the zip a fab takes), `kicad`, `ipc2581` (IPC-2581C), `dsn` (Specctra, for another router), `schematic` (SVG, `--pdf`), `json` |
| `pcbkit parts` | an orderable part for each component (needs the network: PCBKit's parts catalogue) |
| `pcbkit view` | the PCBKit app on localhost with this board: look at it in 2D and 3D, move parts, route |
| `pcbkit call NAME JSON` | any of the 140+ commands of PCBKit's registry, the same ones the web app and the plugins run |
| `pcbkit mcp` | this project's commands as MCP tools for a local agent (stdin/stdout, or `--http ADDR`) |

Everything above works offline except `parts` and the hosted 3D models (`render --3d --models`
fetches the models a board lacks from PCBKit's library; without network the parts are drawn as
boxes from their pads).

## For agents

Read [`AGENTS.md`](AGENTS.md). In short:

- Every command prints one JSON document on stdout: `ok`, `status` (`complete`, `incomplete`,
  `error`), a `summary` sentence that ends with what to do next, and the `result`.
- Exit codes: `0` fine, `1` problems found (the check finds errors, routing left connections
  missing, a command refused), `2` could not run.
- `pcbkit commands` lists every command with its JSON Schemas; `pcbkit call board.get '{"ids":
  ["U1"]}'` runs one. `pcbkit docs --out DIR` writes the agent guide (`agents.md`, `llms.txt`,
  `llms-full.txt`), also at [pcbkit.io/agents.md](https://pcbkit.io/agents.md).
- `pcbkit mcp` serves the same commands as MCP tools to an agent on this computer.

## How it routes

Measured on public benchmarks, each judged the way its authors judge, next to the best published
result (our runs on AWS Graviton4 hosts, PCBKit main of 2026-10-28):

- [PCBWorld-Bench](https://github.com/LGAI-Research/PCBWorld) D3-A, D3-B, D3-C: every board
  completed in every rollout (completion 1.00 on 1,980, 200 and 200 runs), judged by PCBWorld's own
  evaluator; the best published rows are 0.94 and 0.78.
- [Zap!'s scoreboard](https://zap.mutual.solutions/compare) (25 open boards, 1 core, up to 60
  minutes, judged by KiCad 10's DRC): 14 boards fully connected with 0 shorts and 84 errors,
  against Zap!'s 14 with 184 errors in a single run, Freerouting 2.5.0's 11 with 2,318 errors.
- tscircuit's srj19 / srj20 (200 problems each): 200 / 177 solved, against tscircuit's 92 % / 79 %.

## Other ways to use PCBKit

- **In an agent on your computer** (Claude Code, Codex): the
  [PCBKit plugin](https://github.com/pcbkit-io/plugins) runs this binary as its MCP server.
- **In a chat app** (Claude, ChatGPT): the hosted PCBKit connector, from the same plugins.
- **In the browser:** [app.pcbkit.io](https://app.pcbkit.io).

## Help and feedback

[Issues](https://github.com/pcbkit-io/cli/issues) for bugs and wishes (attach the board, or the
smallest board that shows it, when you can). Documentation: [pcbkit.io/docs](https://pcbkit.io/docs).

## For maintainers

Releases are built from PCBKit's private repository by this repository's `release` workflow
(`.github/workflows/release.yml`), started by PCBKit's `make release-cli ARGS=--owner-approved`.
It runs only on the owner's explicit command: nobody else, people or agents, starts, re-runs or
re-dispatches it.

## Licence

The `pcbkit` binary is free to use for any purpose, commercial included; see
[LICENSE.md](LICENSE.md). Its source is not published. The boards you make or change with it are
yours.
