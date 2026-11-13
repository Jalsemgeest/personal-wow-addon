# HookLine — Design Document

A quality-of-life fishing addon for **World of Warcraft: Forever**, built to be
safe to distribute under Blizzard's rules.

Status: **v0.1 (pre-alpha, not yet tested in-game)**

---

## 1. Goals

1. Make fishing low-attention. Players should be able to fish while watching a
   video, without having to listen hard for the splash.
2. Fewer keystrokes and clicks. Use one key to cast and reel, and one command
   to swap your fishing pole in and out.
3. Track what you catch. Keep per-session and lifetime stats by zone, plus
   catch rate and skill gains.
4. Stay within the rules. Every in-game action comes from a deliberate player
   keypress, and the addon makes no external process calls and reads no game
   memory.

### Non-goals (permanent)

- Detecting the bite from outside the game (screen pixels, audio capture,
  memory reading).
- Reeling in, casting, or re-casting without a player keypress.
- Any "AFK fishing" mode, macro looping, or input injection.
- Paid features, advertising, or in-game donation requests.

---

## 2. Blizzard rules review

> **Caveat:** This section is a developer's summary of the policies, not legal
> advice. The official pages could not be fetched directly while this was
> written, so the summary is based on secondary sources (listed at the end of
> this section). Re-read the primary sources before any public release:
> - UI Add-On Development Policy:
>   https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
> - Blizzard End User License Agreement and WoW Terms of Use (blizzard.com/legal)

### 2.1 UI Add-On Development Policy (2009, revised 2010)

| Rule | What HookLine does |
|---|---|
| AddOns must be free of charge (no paywalls or premium tiers) | The addon is entirely free, with no gated features. |
| AddOn code must be completely visible (no obfuscation) | The code is plain Lua and XML with no minification or encoded payloads. |
| AddOns must not negatively impact realm performance | The addon sends no addon-channel or chat spam and does no per-frame heavy work. The OnUpdate handler runs only during a fishing channel. |
| No in-game advertising or donation solicitation | There is none. Donation links, if any, live only on the distribution page. |
| AddOns must not contain offensive material | Nothing offensive is included. |
| Must comply with the WoW Terms of Use / EULA | See 2.2. |
| Blizzard may disable add-on functionality at its discretion | Design for it: degrade gracefully if an API disappears. |

### 2.2 EULA / Terms of Use: the "automation" line

The Terms of Use prohibit "cheats, automation software (bots), hacks, mods or
any other unauthorized third-party software." Blizzard has enforced this
heavily, for example in the 2015 wave of 100k+ six-month bans for "third-party
programs that automate gameplay." Fishing bots have historically been a major
target.

**Approved addons** run inside the client's Lua sandbox. That sandbox enforces
the rule technically: **protected actions** (casting spells, interacting with
objects, targeting) can only run in response to a hardware event (a real key
press or click), through Blizzard's secure templates. If an addon tries to
cast on its own, the call is blocked ("AddOn tried to call a protected
function").

The practical rule HookLine follows: **one keypress → at most one game
action, and the player decides when to press.** HookLine can:

- choose *which* action a key performs (cast vs. reel), using
  `SetOverrideBinding*` out of combat — the same mechanism used by Fishing
  Buddy, EasyFish and Fishing-OneKey;
- change client settings (CVars) such as sound volumes and soft-target
  interact;
- show visual information.

HookLine never does any of the following, and must never do them:

- **Bite detection from outside the client.** Listening to audio, reading
  pixels, or reading memory, then pressing keys, is a bot. A *notification-only*
  external tool is still a grey area, and HookLine does not ship one (see §4.1).
- **Input injection.** No AutoHotkey-style helpers, and no "press any key to
  fish" that maps every key.

### 2.3 WoW Forever specifics

- Forever runs on the **modern client** (the Midnight 12.x engine), not the old
  1.15 Classic Era client. Classic Era addons do not load. The interface number
  reported for launch (client 1.60.1) is **16001**. Verify it in-game:
  `/run print(select(4, GetBuildInfo()))`.
- The modern client means modern APIs: `C_Spell`, `C_Container`, `C_Item`,
  soft-target interact, and the Settings panel API. Several globals from older
  clients are gone, such as `GetSpellInfo` and `GetContainerItemID`, so the
  code always prefers the `C_*` APIs and falls back to the older ones.
- Midnight's **addon restrictions** ("secret values", the combat log closed to
  addons, addon comms blocked in instances) target combat and instances.
  Open-world fishing is unaffected. Still, HookLine reads no combat information
  and sends no addon messages.

### 2.4 Distribution checklist (before a public release)

- [ ] Re-read the UI Add-On Policy and Terms of Use from Blizzard's sites.
- [ ] Confirm the `## Interface:` number against the live client.
- [ ] Get no "ADDON_ACTION_BLOCKED" / taint errors in a full session
      (`/console scriptErrors 1`).
- [ ] Publish on CurseForge / Wago under a free license (see LICENSE), with
      source visible.
- [ ] Make the store page avoid "AFK", "bot" and "auto-fish" wording, and state
      the one-key-one-action design.

Secondary sources used: AddOn Studio's copy of the policy, Engadget's 2009
coverage, PC Gamer's coverage of the 2015 bans, and community WoW Forever addon
guides (forevermeta.me, wowforeverguides.com) for the interface number.

---

## 3. Key technical constraint: there is no bite event

**The WoW API exposes no event or function that fires when a fish bites.**
Blizzard withholds this on purpose, because it is exactly what a bot needs.
Every established fishing addon (Fishing Buddy, EasyFish, Better Fishing,
Angleur) says the same thing. Their only bite cue is **making the splash sound
louder**.

That collides with goal #1, fishing while watching a video, which needs a cue
that does not depend on game audio. The plan has three tiers:

| Tier | Approach | Status |
|---|---|---|
| A | **Make the bobber impossible to miss.** Turn on the soft-target interact icon over the bobber, and show a large on-screen "FISHING" HUD with a cast countdown. The bobber's own splash animation then happens right under a big icon at the center of your view. | v0.1 |
| B | **Splash-sound focus.** While fishing, raise SFX, lower music and ambience, and keep sound playing while WoW is in the background. Restore everything afterwards. This lets the splash cut through a video playing at the same time. | v0.1 |
| C | **Event probe.** A debug mode logs *every* client event fired during a fishing channel, so we can find out empirically whether the Forever client emits anything at bite time, such as a soft-interact change, an animation-kit or sound-related event, or a nameplate update. If a reliable in-client signal exists, it is legitimate to use it: it comes from the game, and the player still presses the key. The large flash alert (`Alert:Bite()`) is already built and waiting for that hook. | v0.1 (tooling); alert wiring after in-game testing |

If tier C finds nothing, the honest product position is "A + B", and the store
page should say so plainly.

---

## 4. Features

### 4.1 Bite Alert / Fishing HUD (`Alert.lua`)
- A large center-screen panel appears while the Fishing channel is active. It
  shows "WATCH THE BOBBER", the key to press, and a progress bar of the
  remaining cast time.
- A full-screen pulse flash API (`HookLine.Alert:Flash()`) is ready for a bite
  signal (§3 tier C). It also fires when the cast expires ("Recast!").
- Soft-target icon CVars make the bobber stand out (`SoftTargetIconGameObject`,
  `SoftTargetIconInteract`).
- Sound focus (tier B) is optional, on by default, and always restored.

### 4.2 One-key cast & reel (`OneButton.lua`)
- The player picks a key: `/hl key F`.
- When **fishing mode** is on (a fishing pole is equipped, or `/hl mode` was
  toggled), the key is override-bound:
  - **not channeling:** it clicks a `SecureActionButtonTemplate` button set to
    `type=spell, spell=<Fishing>` (one press, one cast);
  - **channeling Fishing:** it is bound to `INTERACTTARGET` (one press, one
    interaction with the soft-targeted bobber).
- Bindings can only change out of combat. If combat starts, the overrides are
  cleared, and they are restored when `PLAYER_REGEN_ENABLED` fires.
- Soft-interact CVars are set while fishing mode is active (`SoftTargetInteract=3`
  and a wide arc/range) and restored when it ends.

### 4.3 Weapon swap (`Gear.lua`)
- `/hl gear` (and the HUD button) toggles between the fishing pole and your
  previous main hand and off hand.
- The previous weapons are remembered per character (SavedVariablesPerCharacter).
- Picks the best pole found in your bags (highest item level).
- Works out of combat only, because equipping is restricted in combat.
- Possible later addition: fishing hat and lure application (lures are a
  protected item use on a slot, so that needs a secure button, which is planned).

### 4.4 Fishing tracking (`Tracker.lua`)
- **Session:** casts, catches, "got away" count, catches per hour, and items
  caught.
- **Lifetime:** per zone and subzone, item counts, and totals.
- Tracks fishing skill changes (`SKILL_LINES_CHANGED` / chat skill-up).
- Catches are detected with `LOOT_OPENED` + `IsFishingLoot()`, with a fallback
  of "loot opened within 2s after our fishing channel ended".
- `/hl stats` prints the session summary, and `/hl zone` prints the current
  zone's lifetime table.

### 4.5 Configuration (`Core.lua`)
- SavedVariables: `HookLineDB` (account-wide) and `HookLineCharDB` (per
  character).
- Slash commands now; a Settings-panel UI is on the backlog.

---

## 5. Architecture

```
HookLine/
  HookLine.toc     metadata, load order
  Core.lua         namespace, event bus, saved vars, slash commands, helpers
  Fishing.lua      fishing-state machine (idle / channeling), emits callbacks
  Alert.lua        HUD, flash, sound focus, event probe
  OneButton.lua    secure cast button + override bindings
  Gear.lua         pole swap
  Tracker.lua      session + lifetime stats
tests/
  run.lua          headless tests with a mocked WoW API (lua5.1)
```

- **Event bus:** Each module calls `HookLine:On("EVENT", fn)`. One hidden frame
  dispatches WoW events, and internal messages (e.g. `HL_FISHING_START`) share
  the same bus through `HookLine:Fire()`.
- **API shims:** `HookLine.API` wraps APIs that moved between client
  generations (spell info, container access, item info).
- **No libraries.** There are no Ace3 or LibStub dependencies for now, which
  keeps the code fully visible and small.

## 6. Testing
- `lua5.1 tests/run.lua` loads every module against a mock WoW environment and
  exercises the state machine, tracker, and binding logic.
- In-game smoke test: `/console scriptErrors 1`, then cast, reel, swap, combat
  in and out, `/reload`, and check that saved data persists.

## 7. Roadmap
- v0.1: the features above, the event probe, and slash configuration.
- v0.2: wire the bite signal if the probe finds one, a Settings panel, a
  movable/scalable HUD, and a stats window.
- v0.3: lure application button, fishing outfit (hat/gloves/boots),
  pool tracking, and achievement/rare-catch alerts.
- v1.0: localisation, CurseForge/Wago release.
