# Player Homes (Universal Luanti)

A game-independent Luanti mod that uses standard Luanti APIs and is intended to work with many Luanti games, including Mineclonia, Minetest Game, and other compatible games.

## Features

- `/sethome <name>` — save your current position.
- `/home` — open the home menu.
- `/home <name>` — teleport directly to a home.
- `/homes` — list saved homes.
- `/delhome <name>` — delete a home.
- `/homehelp` — show command help.
- Homes are saved per player and persist through server restarts.
- Menu lets you select, teleport to, delete, and create homes.

## Installation

1. Extract the `playerhomes` folder into your world's `worldmods` folder, or install it in the Luanti mods directory.
2. Enable the mod for the world in the Luanti settings.
3. Restart the world/server.

## Configuration

Add these to `minetest.conf` or the world's configuration:

```ini
# Maximum number of homes per player (default: 20; minimum: 1)
playerhomes_max_homes = 20

# Cooldown between successful home teleports in seconds (default: 10; 0 disables it)
playerhomes_teleport_cooldown = 10
```

## Compatibility notes

- No dependency on a specific game or game-specific nodes/items.
- Uses Luanti's standard mod storage, chat commands, player metadata, vector, and formspec APIs.
- The teleport destination is one node above the saved position; this is a simple precaution, not a full safe-landing check.
- Cooldowns are held in memory and reset when the server restarts.
- Test in a backup world before using on a public server. Exact compatibility may vary with older Luanti versions or games that heavily modify standard behavior.

## License

MIT
