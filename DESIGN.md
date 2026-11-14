# Syl's Tools — Design Document

**Syl's Tools** is a suite of quality-of-life tools for **World of Warcraft:
Forever**, built to be safe to distribute under Blizzard's rules. Each tool is
a self-contained *module* with its own page in the Syl's Tools window.
**Fishing** is the first module.

Status: **v0.3 (pre-alpha, not yet tested in-game)**

Modules:

| Module | What it does | Spec |
|---|---|---|
| **Fishing** | Bobber HUD, one-key cast & reel, weapon swap with auto re-equip, catch tracking | §4 |
| **Upcoming Spells** | "What do I get next level?" in a spellbook tab and in the window | §8 |
| **Class Guides** | Beginner guides per role that adapt to the abilities you have | §9 |

## 0. Suite structure

- **One addon, many modules.** Players install a single addon folder
  (`SylsTools/`). Each tool lives in `Modules/<Name>/` and registers itself
  with `ST:NewModule(key, { title, icon, defaults, charDefaults })`.
- **One window.** `/syl`, or the minimap addon menu, opens the Syl's Tools
  window. A sidebar lists the modules, and each module builds its own page
  (`module:BuildPanel(page)`).
- **Shared services** in `Core.lua`: the event bus, saved variables with
  per-module namespaces (`SylsToolsDB.modules.<key>` and
  `SylsToolsCharDB.modules.<key>`), slash routing (`/syl <module> <command>`),
  API shims, and a CVar stash that always restores settings.
- **Suite-wide rules.** The rules in §2 apply to every module. Each module
  must work on its own and must not depend on another module.

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

| Rule | What Syl's Tools does |
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

The practical rule Syl's Tools follows: **one keypress → at most one game
action, and the player decides when to press.** Syl's Tools can:

- choose *which* action a key performs (cast vs. reel), using
  `SetOverrideBinding*` out of combat — the same mechanism used by Fishing
  Buddy, EasyFish and Fishing-OneKey;
- change client settings (CVars) such as sound volumes and soft-target
  interact;
- show visual information.

Syl's Tools never does any of the following, and must never do them:

- **Bite detection from outside the client.** Listening to audio, reading
  pixels, or reading memory, then pressing keys, is a bot. A *notification-only*
  external tool is still a grey area, and Syl's Tools does not ship one (see §4.1).
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
  Open-world fishing is unaffected. Still, Syl's Tools reads no combat information
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

## 4. Fishing module features

### 4.1 Bite Alert / Fishing HUD (`Alert.lua`)
- A large center-screen panel appears while the Fishing channel is active. It
  shows "WATCH THE BOBBER", the key to press, and a progress bar of the
  remaining cast time.
- A full-screen pulse flash API (`Alert:Flash()`) is ready for a bite
  signal (§3 tier C). It also fires when the cast expires ("Recast!").
- Soft-target icon CVars make the bobber stand out (`SoftTargetIconGameObject`,
  `SoftTargetIconInteract`).
- Sound focus (tier B) is optional, on by default, and always restored.

### 4.2 One-key cast & reel (`OneButton.lua`)
- The player picks a key: the Fishing page key button, or `/syl fishing key F`.
- When **fishing mode** is on (a fishing pole is equipped, or "Always on" was
  toggled), the key is override-bound:
  - **not channeling:** it clicks a `SecureActionButtonTemplate` button set to
    `type=spell, spell=<Fishing>` (one press, one cast);
  - **channeling Fishing:** it is bound to `INTERACTTARGET` (one press, one
    interaction with the soft-targeted bobber).
- **Game Key Bindings entry.** `Bindings.xml` adds *Options > Keybindings >
  AddOns > Syl's Tools > Fishing: Cast / Reel*, which clicks the same secure
  cast button. A key bound there casts as a normal binding, and while a Fishing
  channel is active it is temporarily overridden to `INTERACTTARGET` so the same
  key reels in. Unlike the Syl's Tools key, it is bound at all times, which suits
  players who prefer a dedicated key.
- Bindings can only change out of combat. If combat starts, the overrides are
  cleared, and they are restored when `PLAYER_REGEN_ENABLED` fires.
- Soft-interact CVars are set while fishing mode is active (`SoftTargetInteract=3`
  and a wide arc/range) and restored when it ends.

### 4.3 Weapon swap (`Gear.lua`)
- **Automatic weapon tracking.** Whenever your main hand is *not* a fishing
  pole, your current main hand and off hand are recorded as "your weapons", per
  character. This works however the pole gets equipped: with the Syl's Tools
  button, `/syl fishing gear`, or dragging it on by hand.
- **Equip Pole** equips the best pole in your bags (highest item level).
  **Re-equip My Weapons** puts your recorded weapons back, main hand first and
  then off hand, because a two-handed pole fills both slots.
- **Auto re-equip when done fishing** is on by default. When a cast ends, a
  countdown starts (60s by default, adjustable from 10 to 600s). Casting again
  cancels it. When it runs out, your weapons go back on. If you're in combat at
  that moment, the swap waits until combat ends.
- Equipping happens out of combat only. This is gear management, the same thing
  ItemRack and Outfitter do, not gameplay automation: it doesn't cast,
  target or interact with anything.
- Possible later additions: an in-combat emergency swap through a secure macro
  button, a fishing outfit (hat/gloves/boots), and lure application (a
  protected item use, so it needs a secure button).

### 4.4 Fishing tracking (`Tracker.lua`)
- **Session:** casts, catches, "got away" count, catches per hour, and items
  caught.
- **Lifetime:** per zone and subzone, item counts, and totals.
- Tracks fishing skill changes (`SKILL_LINES_CHANGED` / chat skill-up).
- Catches are detected with `LOOT_OPENED` + `IsFishingLoot()`, with a fallback
  of "loot opened within 2s after our fishing channel ended".
- `/syl fishing stats` prints the session summary, and `/syl fishing zone` prints the current
  zone's lifetime table.

### 4.5 Fishing page (`Panel.lua`)
The Fishing page in the Syl's Tools window has two columns:

| Left | Right |
|---|---|
| **Weapon Swap**: Main Hand and Off Hand slot icons (your recorded weapons, with item tooltips) → Fishing Pole icon; a big *Equip Fishing Pole* / *Re-equip My Weapons* button; a live status line ("Re-equipping weapons in 0:42. Cast again to cancel."); an auto re-equip checkbox and a ± delay control | **Bobber Alerts**: checkboxes for the HUD, the expiry flash, the bobber icon and sound focus; *Move HUD* and *Test Alert* buttons |
| **One-Key Fishing**: a click-to-bind key button (keyboard with modifiers, or mouse buttons 4/5), a Clear button, an active/inactive status line, and an "Always on" checkbox | **This Session**: casts, catches, catch rate, catches per hour, got away, skill gain, and the top catches; *Reset Session* and *Zone Stats* buttons |

The page refreshes on game events, and updates four times a second while
visible to keep the countdown live.

### 4.6 Configuration
- SavedVariables: `SylsToolsDB` (account-wide) and `SylsToolsCharDB` (per
  character), each namespaced by module.
- Everything is configurable from the window. Slash commands mirror the window:
  `/syl fishing <command>`.

---

## 5. Architecture

```
SylsTools/
  SylsTools.toc          metadata, load order, addon-compartment hook
  Bindings.xml           Key Bindings menu entries
  Core.lua               namespace, event bus, module registry, saved vars, /syl, API shims
  Spellbook.lua          shared spellbook scanner (known spells, ranks, future spells)
  UI/
    Widgets.lua          header, button, checkbox, stepper, item slot, key-bind capture, scroll list
    MainFrame.lua        window + module sidebar
  Modules/
    Fishing/
      Fishing.lua        module definition, defaults, spell/pole helpers
      State.lua          fishing-state machine (idle / channeling)
      Alert.lua          HUD, flash, sound focus, event probe
      OneButton.lua      secure cast button + override bindings
      Gear.lua           weapon tracking, pole swap, auto re-equip
      Tracker.lua        session + lifetime stats
      Panel.lua          the Fishing page in the window
    Spells/
      Spells.lua         trainer capture, upcoming-spell model, level-up notice
      SpellbookTab.lua   tab + side panel on the spellbook
      Panel.lua          the Upcoming Spells page
    Guides/
      Guides.lua         guide registry, role suggestion, ability state -> rows
      Data/Warrior.lua   Warrior Tank + Damage/Levelling guides
      Panel.lua          the Class Guides page
tests/
  run.lua                headless tests with a mocked WoW API (lua5.1)
```

- **Event bus:** Each module calls `ST:On("EVENT", fn)`. One hidden frame
  dispatches WoW events, and internal messages (e.g. `ST_FISHING_START`,
  `ST_GEAR_CHANGED`) share the same bus through `ST:Fire()`.
- **API shims:** `ST.API` wraps APIs that moved between client generations
  (spell info, container access, item info, timers).
- **Safe event registration:** registering an event the client doesn't know is
  wrapped in `pcall`, because modern clients throw on unknown events. This
  keeps the suite working if WoW Forever lacks a classic-era event.
- **No libraries.** There are no Ace3 or LibStub dependencies for now, which
  keeps the code fully visible and small.

## 6. Testing
- `lua5.1 tests/run.lua` loads every module against a mock WoW environment and
  exercises the state machine, tracker, and binding logic.
- In-game smoke test: `/console scriptErrors 1`, then open `/syl` and go
  through each control. Then cast, reel, swap, wait for the auto re-equip, test
  combat in and out, `/reload`, and check that saved data persists.

## 7. Roadmap
- v0.1: fishing features, the event probe, and slash configuration.
- v0.2: Syl's Tools suite structure, the main window and Fishing page,
  automatic weapon tracking, and auto re-equip.
- v0.3: the Upcoming Spells module (spellbook tab), the Class Guides module
  (Warrior first), and the Key Bindings menu entry for fishing.
- v0.3.1: controller groundwork: a native Settings page, binding controller
  buttons, and controller button names in the HUD (§10). *(current)*
- v0.3.x: guides for the remaining classes, and wiring the bite signal if the
  probe finds one.
- v0.4: a lure button, a fishing outfit, and a minimap button.
- v1.0: localisation, CurseForge/Wago release.

## 8. Upcoming Spells module

**Goal:** answer "what do I get at my next levels, and what can I train right
now?" without leaving the game. This is the same idea as the "What's Training"
style of addon, built into the suite.

### 8.1 Data: read from the game, not bundled
WoW Forever has its own revamped 1-60 content, so a bundled spell/level table
copied from old Classic data could be wrong. Instead:
1. **Class trainer capture.** When the player opens their class trainer
   (`TRAINER_SHOW`, skipping profession trainers), every service is read with
   the "available / unavailable / used" filters all switched on. That covers
   spells you're too low for as well. The player's own filter settings are
   restored straight afterwards. The data is stored **per class, account-wide**
   (`SylsToolsDB.modules.spells.trainer[CLASS]`), so alts benefit too: name,
   rank, level requirement, cost and icon.
2. **Spellbook "future spells".** If the client lists unlearned spells in the
   spellbook (modern `C_SpellBook` `FutureSpell` items or the classic
   `FUTURESPELL` type), they are merged in, with their level from
   `GetSpellLevelLearned`.

Possible later addition: a bundled seed list, used only until the first
trainer visit, if the game data turns out to be stable.

### 8.2 Model
- *Known* is decided by the shared spellbook scanner (`Spellbook.lua`), by name
  and rank. Knowing a higher rank counts as knowing a lower one.
- **Ready to train:** level requirement ≤ your level and not known, with the
  total cost.
- **Upcoming:** grouped by level, with the next level highlighted. It shows the
  next 10 levels by default, or every level if you choose.

### 8.3 UI
- **Spellbook tab.** A tab on the right edge of the spellbook (classic
  `SpellBookFrame` or modern `PlayerSpellsFrame`, which loads on demand)
  toggles a side panel docked next to the book. It is attached only with
  `HookScript` (OnShow/OnHide), with no Blizzard functions replaced, to avoid
  taint. It remembers whether it was open.
- **Window page.** The same list, plus settings: show the spellbook tab, show
  every level, and a level-up chat notice.
- **Level-up notice.** "Level 14! New at your trainer: Revenge,
  Demoralizing Shout".

## 9. Class Guides module

**Goal:** new players get in-game, plain-language help for the role they
want to play, based on the abilities they *actually have right now*. Example: a
new Warrior who wants to tank learns that Sunder Armor is their threat button
at level 10, that Revenge comes at 14, and what to do when an enemy runs to
the healer.

### 9.1 Content model
Guides are data files (`Modules/Guides/Data/<Class>.lua`), one per role:
- `intro`: what the role is about, in plain words.
- `sections`: themed groups such as "Before the pull", "Pulling", "One enemy:
  what to press" (priority order), "Several enemies", "An enemy is attacking
  someone else", and "Emergencies".
- `entries`: either an **ability** (`spell` ID plus a fallback `name`,
  optional `stance` and `talent` flags, and a `text` on how and when to use it)
  or a **tip** (plain advice).

### 9.2 Adapting to the player
- Abilities you know are shown in full colour. Ones you don't know yet are
  greyed out with "unlocks at level N". That level comes from the Upcoming
  Spells trainer data when available, otherwise from a hint in the guide.
  Talents are labelled "talent".
- "Only show abilities I have" collapses the guide to what you can press today.
- The player picks the role they want to read about. The choice is saved per
  character, and the first guide is the default.
- Matching is by spell **name**, so ranks don't matter, and a spell ID that
  differs on Forever still works through the fallback name.

### 9.3 Content status
- **Warrior: Tank (Protection)** and **Damage & Levelling (Arms/Fury)** are
  written.
- Other classes show a "coming soon" message. The plan is to add a Tank,
  Healer or Damage guide for each class as appropriate, starting with the
  roles new players struggle with most: tanks and healers.
- The content describes classic-style mechanics. Abilities WoW Forever changes
  need their text updated.

### 9.4 Scope: text only (permanent)
Guides are **reference text you read**, like a beginner's guide that knows
which abilities are in your spellbook. The only character information they
use:
- which abilities you have (the spellbook scanner), and
- the trainer level for abilities you don't have yet (Upcoming Spells data).

They never read talents, combat state, targets, cooldowns, rage or auras.
They show nothing during combat, and there is no "press this next"
highlighting. This keeps them far from rotation automation, and unaffected by
the client's combat-data restrictions.

## 10. Controller support (WoW Forever Gamepad UI)

### 10.1 Research findings (Nov 2026)
- **Native support is a beta.** WoW Forever launched with a native controller
  interface ("Gamepad UI") that Blizzard calls a *functional beta*. According
  to third-party guides that quote Blizzard's posts, the Nov 2 patch notes
  mention improving "Gamepad UI compatibility with user-created add-ons".
  Turning it on: `GamePadEnable 1` and `InputDeviceInterfaceStyle 1`. Addons
  can detect it with `InputUtil.IsGamepadUIEnabled()`.
- **The controller cursor only reaches what the client builds.** Custom addon
  frames aren't part of its navigation:
  - Bag replacements like BetterBags can't be navigated. Its maintainer said:
    "Blizzard does not allow add-ons to hook into their new UI. When they add
    this, BetterBags will support it."
  - Baganator needs a separate "Baganator Gamepad" bridge addon.
  - This is almost certainly why **Bagnon's bags won't open on controller**:
    the controller's bag action targets Blizzard's bag frames, which Bagnon
    replaces with frames the controller UI doesn't know about. This is an
    inference, not confirmed.
- **Settings pages are the exception.** Pages registered in Blizzard's Options
  panel with the *vertical layout* (`Settings.RegisterVerticalLayoutCategory`,
  proxy settings, checkboxes, sliders and initializers) are reachable by the
  controller cursor. *Canvas* pages (a custom frame inside Settings) are not:
  the cursor lands on an invisible row. Confirmed in a merged fix in another
  Forever addon (legacy-forever, PR #335).
- **Low-level API.** Since 9.0 the client has had `C_GamePad`, and any frame
  can take controller input directly with `Frame:EnableGamePadButton(true)`
  and `OnGamePadButtonDown`. Only the top-most frame with controller input
  enabled receives it. Controller buttons bind like keys (`PAD1`, `PADDDOWN`,
  `PADLTRIGGER`, ...).
- **The ecosystem already exists:** ConsolePort (with an interim Forever
  version), Controller Forever, Gamepad Suite, Improved Forever (radial
  wheels, vibration, controller auction house), Controller Companion, and
  WorldController. Some need Blizzard's Gamepad UI **on** (Controller
  Forever) and others need it **off** (WorldController), so they don't all mix.

### 10.2 What it means for Syl's Tools
Our window is a custom frame, so **controller players can't use it** while
the Gamepad UI is on. The same goes for the spellbook tab and side panel.

### 10.3 Done (v0.3.1)
- **Native Settings page** (`UI/Settings.lua`) under Options > AddOns >
  Syl's Tools, built with the vertical layout so the controller cursor can
  reach it. It has every setting a controller player needs, plus a native
  **keybinding row for Fishing: Cast / Reel**, so a pad button can be bound
  there. Each row is pcall-guarded, and missing APIs just skip that row.
- **Controller buttons in the key picker.** The Fishing page's key button
  accepts controller buttons (`OnGamePadButtonDown`) as well as keys.
- **Controller button names in the HUD.** The HUD and key labels use
  `GetBindingText`, which shows controller button glyphs where the client
  supports them.
- **The minimap addon menu** opens the Settings page instead of the window
  while the Gamepad UI is on.
- Fishing is a natural fit for controller play: one button casts and reels,
  and the weapon swap happens on its own.

### 10.4 Next ideas (need in-game testing first)
1. **Our own controller navigation in the Syl's Tools window.** While it's
   open, the window takes controller input itself (`EnableGamePadButton`):
   d-pad to move between controls, A to press, B to close, and the bumpers to
   switch modules. Only the top-most frame with controller input enabled gets
   buttons, so this must be switched off when the window closes. It's worth
   checking how it interacts with the Gamepad UI cursor.
2. **Controller-friendly Class Guides.** A reading mode you can scroll with the
   stick, and the guide text in the native Settings page.
3. **Rumble cues** (`C_GamePad.SetVibration`) for "cast expired, recast" and
   "weapons re-equipped". This gives a cue that needs neither sound nor a
   glance at the screen.
4. **Controller addon profile.** Detect switching between controller and
   keyboard & mouse, and offer to swap incompatible addons, such as disabling
   Bagnon and using the default bags while on controller. This uses
   `C_AddOns.DisableAddOn`/`EnableAddOn` plus a reload prompt that the player
   confirms. It doesn't fix Bagnon, but it removes the "my bags won't open"
   trap.
5. **Compatibility notes.** Test alongside ConsolePort and Controller Forever
   and document conflicts.
