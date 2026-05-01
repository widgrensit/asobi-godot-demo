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

   Server listens on `http://localhost:8085`. (This demo plays the *full* arena game — boons, modifiers, voting, bots — so it needs the arena Lua, not the minimal [`sdk_demo_backend`](https://github.com/widgrensit/sdk_demo_backend).)

### Install SDK

Symlink or copy the asobi-godot SDK into the `addons/` directory:

```bash
ln -s /path/to/asobi-godot/addons/asobi addons/asobi
```

### Run

1. Make sure `asobi_arena_lua` is up (see Prerequisites).
2. Open this project in Godot 4.5.
3. Press F5 to run.

## Architecture

All UI is built programmatically in GDScript (no .tscn editor dependencies beyond root nodes). Server-authoritative gameplay at 10 Hz tick rate — the client only renders state received from the backend.

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move |
| Mouse | Aim |
| Left Click | Shoot |
