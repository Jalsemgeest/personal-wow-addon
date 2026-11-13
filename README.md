# HookLine

A low-attention fishing addon for **World of Warcraft: Forever**. HookLine
doesn't automate anything: every cast and reel-in is a keypress you make.
Read [DESIGN.md](DESIGN.md) for scope, the Blizzard rules review, and the
roadmap.

## Features (v0.1)
- **Fishing HUD**: a large "WATCH THE BOBBER" panel with a cast countdown, and
  a full-screen flash when your cast expires.
- **Bobber visibility**: the soft-target icon sits over your bobber.
- **Splash-sound focus**: while you fish, SFX goes up and music and ambience
  go down, and sound keeps playing while WoW is in the background. Your
  settings are restored afterwards.
- **One-key cast & reel**: the same key casts Fishing, then interacts with the
  bobber.
- **Pole swap**: one command swaps your fishing pole in and out.
- **Tracking**: session and lifetime catches, broken down by zone and item,
  plus skill-ups.

## Install
Copy the `HookLine/` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
The folder name has not been confirmed for every client build. Use the one
that sits next to your `Wow` executable.

## Commands
```
/hl key F       set the one-key cast & reel key
/hl mode        force fishing mode on/off (it normally follows your equipped pole)
/hl gear        swap pole <-> weapons
/hl stats       session stats            /hl zone   lifetime stats for this zone
/hl hud | move | scale 1.2 | sound | flash
/hl probe       developer: log client events during a cast (bite-signal research)
```

## Development
```bash
lua5.1 tests/run.lua
```
