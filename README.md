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
- An [`asobi_arena_lua`](https://github.com/widgrensit/asobi_arena_lua) backend running locally:

   ```bash
   git clone https://github.com/widgrensit/asobi_arena_lua
   cd asobi_arena_lua && docker compose up -d
   ```

   Server listens on `http://localhost:8085`. (This demo plays the *full* arena game - boons, modifiers, voting, bots - so it needs the arena Lua, not the minimal [`sdk_demo_backend`](https://github.com/widgrensit/sdk_demo_backend).) On Windows and macOS this needs Docker Desktop running; on Windows use the WSL2 backend.

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

1. Make sure `asobi_arena_lua` is up (see Prerequisites).
2. Open this project in Godot 4.5 and run it (F5). This is the same on every OS. New
   to Godot? See the [Godot docs](https://docs.godotengine.org/).

## Architecture

All UI is built programmatically in GDScript (no .tscn editor dependencies beyond root nodes). Server-authoritative gameplay at 10 Hz tick rate — the client only renders state received from the backend.

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move |
| Mouse | Aim |
| Left Click | Shoot |
