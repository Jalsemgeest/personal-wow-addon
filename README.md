# Syl's Tools

A suite of quality-of-life tools for **World of Warcraft: Forever**. Each tool
is a module with its own page in the Syl's Tools window. Nothing in it
automates gameplay: every cast, reel-in and interaction is a keypress you make.

See [DESIGN.md](DESIGN.md) for scope, the Blizzard rules review, and the
roadmap.

## Modules

### Fishing
- **Fishing HUD**: a large "WATCH THE BOBBER" panel with a cast countdown, a
  full-screen flash when your cast expires, and an icon over your bobber.
- **Splash-sound focus**: while you fish, effects go up, music and ambience go
  down, and sound keeps playing in the background. Your settings are restored
  afterwards.
- **One-key cast & reel**: the same key casts, then reels in when you press it
  on the splash.
- **Weapon swap**: Syl's Tools remembers your weapons automatically and swaps
  in your best pole with one click. Once you've stopped fishing for a while
  (60s by default), it puts your weapons back on its own.
- **Tracking**: session and lifetime catches by zone and item, catch rate, and
  skill-ups.

## Install
Copy the `SylsTools/` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
The folder name has not been confirmed for every client build. Use the one
that sits next to your `Wow` executable.

## Usage
Open the window with **`/syl`**, or from the minimap's addon menu.

Slash commands mirror the window:
```
/syl                          open/close the window
/syl fishing gear             swap pole <-> weapons
/syl fishing autorestore 90   re-equip weapons 90s after you stop fishing (or "off")
/syl fishing key F            one-key cast & reel key
/syl fishing stats | zone     session / zone stats
/syl help                     all commands
```

## Development
```bash
lua5.1 tests/run.lua
```
