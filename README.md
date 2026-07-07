# Asobi Arena Demo (Godot 4.x)

Top-down arena shooter demo for the [Asobi](https://github.com/widgrensit/asobi) game backend, built with Godot 4.5 and the [asobi-godot](https://github.com/widgrensit/asobi-godot) SDK.

## Game Flow

1. **Login** — Register or login with username/password
2. **Lobby** — Connect via WebSocket, find match through matchmaker
3. **Arena** — WASD movement, mouse aim + click to shoot, 90-second rounds
4. **Results** — Match standings, leaderboard submission, play again or quit

## Setup

### Prerequisites

- [Godot 4.5+](https://godotengine.org/)
- The [asobi CLI](https://github.com/widgrensit/asobi-cli) and Docker (for `asobi dev`).

### Run the backend

The full arena game logic (boons, modifiers, voting, bots) is bundled in `lua/`.
Start it locally with one command:

```bash
asobi dev
```

That serves the backend on `http://localhost:8084` and hot-reloads the `lua/` on save.
On Windows and macOS you need Docker Desktop running; on Windows use the WSL2 backend.
Leave it running.

### Install SDK

Add the [`asobi-godot`](https://github.com/widgrensit/asobi-godot) SDK's `addons/asobi`
into this project's `addons/` directory. Clone the SDK next to this demo, then **copy
it in - works on every OS with no admin rights:**

- Windows (PowerShell): `Copy-Item -Recurse ..\asobi-godot\addons\asobi addons\asobi`
- Linux / macOS: `cp -r ../asobi-godot/addons/asobi addons/asobi`

If you plan to edit the SDK in place, link it instead of copying:

- Windows (Developer Mode or admin), cmd: `mklink /J addons\asobi C:\path\to\asobi-godot\addons\asobi`
- Linux / macOS: `ln -s /path/to/asobi-godot/addons/asobi addons/asobi`

### Run

1. Start the backend with `asobi dev` (see above), and copy in the SDK.
2. Open this project in Godot 4.5 and run it (F5), then pick **LOCAL** on the server
   screen. Same on every OS. New to Godot? See the [Godot docs](https://docs.godotengine.org/).

## Architecture

All UI is built programmatically in GDScript (no .tscn editor dependencies beyond root nodes). Server-authoritative gameplay at 10 Hz tick rate — the client only renders state received from the backend.

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move |
| Mouse | Aim |
| Left Click | Shoot |
