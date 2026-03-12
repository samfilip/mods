# Co-op Leaderboard Mod — Research Notes

## Overview

This mod shows a per-player stats leaderboard at the end of co-op runs in Slay the Spire 2.

---

## 1. Game Engine & Mod Stack

| Layer | Technology |
|---|---|
| Game engine | Godot 4 (open source) |
| Game logic | C# / .NET 8, compiled to `sts2.dll` |
| Mod loader | Native — game supports mods via `Slay the Spire 2/mods/` directory |
| Patching library | [HarmonyLib](https://github.com/pardeike/Harmony) (runtime method patching) |
| Distribution | Steam Workshop (natively supported) and [Nexus Mods](https://www.nexusmods.com/games/slaythespire2) |
| Mod manager | Thunderstore / R2Modman (community, optional) |

STS1 tools (ModTheSpire, BaseMod) are **incompatible** — full rewrite required.

---

## 2. How Mods Are Structured

A mod is a folder inside `Slay the Spire 2/mods/<ModName>/` containing:

```
CoopLeaderboard/
├── CoopLeaderboard.dll       # Compiled C# assembly
├── CoopLeaderboard.pck       # Godot resource package (scenes/assets)
└── mod_manifest.json         # Mod metadata
```

### Entry Point

```csharp
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Modding;

[ModInitializer(nameof(Initialize))]
public partial class MainFile : Node
{
    private const string ModId = "CoopLeaderboard";
    public static MegaCrit.Sts2.Core.Logging.Logger Logger { get; } =
        new(ModId, MegaCrit.Sts2.Core.Logging.LogType.Generic);

    public static void Initialize()
    {
        var harmony = new Harmony(ModId);
        harmony.PatchAll();
    }
}
```

Key namespaces confirmed from existing mods:
- `MegaCrit.Sts2.Core.Modding` — mod initializer attribute, logging
- `HarmonyLib` — runtime patching
- `Godot` — UI (CanvasLayer, nodes, signals)

### Build System

- **SDK**: .NET 9.0
- **Also requires**: Godot 4.x Mono (to compile `.pck` resource files)
- **Project file**: `.csproj` referencing `sts2.dll`, `0Harmony.dll`, `Steamworks.NET.dll`
- **Optional base library**: `Alchyr.Sts2.BaseLib` (NuGet package, adds helpers)

### Useful Templates / Starting Points

- [`Alchyr/ModTemplate-StS2`](https://github.com/Alchyr/ModTemplate-StS2) — official empty mod template with BaseLib
- [`lamali292/sts2_example_mod`](https://github.com/lamali292/sts2_example_mod) — example with patches and a custom relic
- [`freude916/sts2-quickRestart`](https://github.com/freude916/sts2-quickRestart) — simple save/load mod

---

## 3. Co-op Mode Details

- Up to **4 players** per run
- Players take turns **simultaneously**; actions resolve one at a time
- Shared debuffs (Weak/Vulnerable applied by one player benefit all)
- **Map voting** at forks
- No public matchmaking (Steam invite only as of Early Access)
- **Co-op exclusive cards** exist for each character
- Run ends on **full party wipe**; individual deaths result in revival at 1 HP after combat

---

## 4. Existing Stats Mods to Study

### MultiplayerStats (Nexus Mods #41)
- Author: Pottymouth222, v0.1.0, uploaded March 11 2026
- **In-combat** overlay showing per-player: current fight damage, cumulative run damage, block gained, run damage graph
- Togglable overlay
- **Does not** show an end-of-run summary screen — this is the gap our mod fills

### STS2-DamageTracker (GitHub: BAIGUANGMEI)
- Multiplayer damage monitor with Chinese locale support
- **Architecture** (most relevant for our mod):
  - `ModEntry.cs` — Harmony patch registration, hooks into 4 events:
    - `BeforeCombatStart`
    - `AfterCombatEnd`
    - `AfterPlayerTurnStart`
    - `AfterDamageGiven`
  - `RunDamageTrackerService.cs` — stat accumulation, JSON persistence to `user://damage_tracker_state.json`, thread-safe with `SyncRoot`
  - `ReflectionHelpers.cs` — runtime reflection to read player/run state
  - `DamageTrackerOverlay.cs` — Godot `CanvasLayer` UI

---

## 5. Game State: Known Fields & Reflection Targets

Since the game's C# API isn't fully documented, existing mods use **runtime reflection** on `sts2.dll` objects. Fields confirmed accessible:

### Run Identification
| Field | Type | Notes |
|---|---|---|
| `Seed` | ? | Run seed |
| `RunId` | ? | Unique run identifier |
| `StringSeed` | string | Human-readable seed |

### Player / Creature Resolution
Fields tried in order until non-null: `Player`, `OwnerPlayer`, `Owner`, `Controller`, `Summoner`, `SourcePlayer`, `Creature`, `Dealer`

### Player Identification
| Field | Notes |
|---|---|
| `NetId` | Network player ID |
| `PlayerId` | In-session ID |
| `LocalPlayerId` | Local player ID |

### Player Name
Fields tried: `DisplayName`, `CharacterName`, `Name`, `LocalizedName`

### Character Data
| Field | Notes |
|---|---|
| `Character` / `CharacterModel` | Character reference |
| `CharacterId` | String ID |
| `Title` | Display name |
| `CharacterSelectIcon` / `IconTexture` | Portrait texture |

### Damage Values
Fields tried: `DamageDealt`, `FinalDamage`, `ActualDamage`, `UnblockedDamage`, `Amount`, `Damage`

### Run Patch Target (from example mod)
```csharp
// Harmony patch target — player creation
[HarmonyPatch("Player.CreateForNewRun")]
// Parameters: CharacterModel, UnlockState, ulong
```

---

## 6. Stats to Show on the Leaderboard

Based on what existing mods track and what the game exposes, the leaderboard can feasibly show:

### Confirmed Trackable (via `AfterDamageGiven` hook)
- **Total damage dealt** (all fights in run)
- **Highest single hit**
- **Per-fight damage** (via `AfterCombatEnd` reset)
- **Total block generated** (via `AfterPlayerTurnStart`)

### Likely Trackable (via additional Harmony patches on game methods)
- **Cards played** — patch the card-play method
- **Gold earned** — patch gold-gain methods (gold is a field on Player, e.g. `Player.Gold`)
- **Potions used** — patch potion use method
- **Relics collected** — patch relic-add method
- **HP at end of run** — read player HP field at run end
- **Times died / revived** — patch death/revive methods
- **Enemies killed** — patch creature death method
- **Elites killed / Bosses killed** — check creature type on death

### Requires Finding Run-End Hook
The biggest open question is **when to show the leaderboard**. Need to find:
- A `RunComplete`/`VictoryScreen`/`RunSummary` class in the decompiled `sts2.dll`
- OR patch the method that transitions to the post-run screen
- Use ILSpy to decompile `sts2.dll` and search for the victory/run-end screen class

---

## 7. UI Approach

Use Godot's scene system for the leaderboard overlay:

- Create a `.tscn` scene (packaged into `.pck`) with a `CanvasLayer` containing a table/panel
- Or inject a Godot `Control` node dynamically from C# at run-end using `GetTree().Root.AddChild(leaderboardNode)`
- Display each player's row with character icon, name, and stat columns
- Show after the boss kill / run completion, before or alongside the native victory screen

Pattern from DamageTracker: use `CanvasLayer` as a non-interfering overlay.

---

## 8. Key Open Questions (Require Decompilation)

1. **What is the run-end class/method name?** — Decompile `sts2.dll` with ILSpy and search for `Victory`, `RunEnd`, `RunComplete`, `WinScreen`
2. **Is there a native run stats object?** — STS1 had `AbstractDungeon` with run data; STS2 likely has an equivalent
3. **How to detect run type (co-op vs solo)?** — Check player count or a co-op flag on run state
4. **Multiplayer player enumeration** — How to get a list of all connected players; likely a `Players` collection on a `RunManager` or `CombatManager` equivalent
5. **Are game events/signals available?** — Godot uses signals; the game may expose C# events rather than requiring Harmony patches for some hooks

---

## 9. Implementation Plan

### Phase 1: Setup
1. Clone `Alchyr/ModTemplate-StS2` as base
2. Install .NET 9.0 SDK and Godot 4.x Mono
3. Set game path in `.csproj` (`local.props`)
4. Decompile `sts2.dll` with ILSpy — find run-end and player-list classes

### Phase 2: Stat Tracking
1. Add Harmony patches for `AfterDamageGiven`, card play, block gain, gold gain, death
2. Build `LeaderboardService` to accumulate per-player stats across the run (similar to `RunDamageTrackerService`)
3. Key on player `NetId` or `PlayerId`

### Phase 3: Leaderboard UI
1. Create Godot `.tscn` scene: table with player rows (icon, name, stat columns)
2. Hook into run-end event/method to instantiate and display the scene
3. Include a "close/dismiss" button

### Phase 4: Polish
1. Detect and only activate in co-op (2+ players)
2. Sort by chosen stat (damage default)
3. Add tooltips for each stat column
4. Test with 2–4 players

---

## 10. References

- [lamali292/sts2_example_mod](https://github.com/lamali292/sts2_example_mod) — STS2 example mod with Harmony patches
- [Alchyr/ModTemplate-StS2](https://github.com/Alchyr/ModTemplate-StS2) — recommended starting template
- [Alchyr/BaseLib-StS2](https://github.com/Alchyr/BaseLib-StS2) — optional base library
- [BAIGUANGMEI/STS2-DamageTracker](https://github.com/BAIGUANGMEI/STS2-DamageTracker) — closest existing mod; study its hooks and reflection patterns
- [MultiplayerStats on Nexus](https://www.nexusmods.com/slaythespire2/mods/41) — fills gap in combat; our mod fills the post-run gap
- [ptrlrd/spire-codex](https://github.com/ptrlrd/spire-codex) — STS2 decompiled card/data database
- [freude916/sts2-quickRestart](https://github.com/freude916/sts2-quickRestart) — simple mod for structure reference
- [Nexus Mods — STS2](https://www.nexusmods.com/games/slaythespire2/mods) — browse all existing mods
- [GitHub slaythespire2 topic](https://github.com/topics/slaythespire2) — all tagged repos
