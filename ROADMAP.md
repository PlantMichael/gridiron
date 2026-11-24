# Gridiron development roadmap

Updated November 24, 2026. This records the agreed development order so the plan
is available from any checkout. Priorities 1–3 are implemented; priority 3 still
needs player balance testing. Priority 4 is next. Future content counts below
remain proposals, rather than features already in the game.

The shared broadcast menu is implemented across gameplay screens and the title.
Match speed, camera and stats are grouped in Menu instead of the field HUD.
This UI pass does not complete priority 4’s introductions.

Shared motion now covers menu entry, button feedback, lineup selection, shop
tabs and match/result panels. Reduced Motion is available on the title and pause
menu for the current session. Team/QB introductions and the versus splash remain
unfinished.

Manual passing is implemented: numbered receiver circles, live Dexterity, and
keyboard or click throws. Auto mode retains AI passing and priority targets.
New runs start Manual; the choice carries between matches during a run.

## Priorities

| Priority | Status | Work and intended result |
|---|---|---|
| 1 | Complete | **Branding and loading.** Rename the game and repository to Gridiron, add the turf loading bar and animated player, and prepare the players and sidelines before revealing a match. Preserve existing QB/bowl completion records. |
| 2 | Complete | **Lineup and shop clarity.** Show the selected starter, eligible replacements and stat comparisons. Use explicit Start, Swap, Equip and Unequip actions. Explain purchase destinations, lab costs, and ritual player losses before confirmation. |
| 3 | Implemented; balance testing pending | **Remove touchdown buffs and add drive events.** Touchdowns retain points and football bucks, with no stat-buff picker. Each drive can roll oil, bottles, an extra defender or Aura Farm, increasingly often deeper into a run. |
| 4 | Menu and panel animation implemented; introductions planned | **Run, match and result presentation.** Introduce the team and QB at run start, show a team-versus-team match splash, and review win/loss/tie presentation. Shared menu entry, selection feedback and match/result reveals are implemented. Make repeated introductions skippable. |
| 5 | Planned | **Head variety.** Add hair and facial-hair styles. Check all facings, portraits, skin-matched hands and collars, including sideline NPCs. Suggested first batch: 8–12 generic styles. |
| 6 | Planned | **Items and recognizable sets.** Explain set membership, equipped-piece progress and active bonuses before purchase or equipping. Define set bonuses before expanding the item pool; suggested first batch: three sets of three pieces. |
| 7 | Planned | **More Oddity and Cursed players.** Add distinct abilities that complement existing builds and explain their strengths and drawbacks during acquisition. Keep Cursed names demon-themed. Suggested first batch: three of each. |
| 8 | Venues, journeys and route events implemented; additional players planned | **Complete bowl identities.** Add unique players or gimmicks to the four bowls without special defenders, then review the existing Pro Bowl and Toilet Bowl effects. Explain every gimmick and provide meaningful counterplay. |

## Drive events: implemented first pass

Touchdown stat-buff choices are removed. Touchdowns still score points and award
football bucks; player abilities and run-map match bonuses remain supported.

The initial tuning values are:

- The first match has no random drive events. From the second match, roll once at the start of each offensive drive.
- Start at 30% in the second match, add 10 percentage points per completed match, and cap at 65%.
- Select at most one event per drive, equally among the four originals and eligible route additions.
- Announce the effect before the snap and explain its duration.
- Clear drive-specific effects before rolling the next event.
- Include beneficial and disruptive events, then rebalance complete runs.

| Event | Current behavior |
|---|---|
| Oil spill | Three marked patches slow either team to 65% speed. Rain uses the stronger slowdown. |
| Fans throwing bottles | Up to two throws total per drive across non-kick plays, with fixed landing zones and 1.25 seconds of warning. Anyone within two yards at impact is stunned for 0.65 seconds. |
| Extra defender | One additional linebacker covers a shallow zone for the drive, then leaves. |
| Aura farm | Your team gains +1 STR, AGI, DEX and INT for the drive, including substitutes; normal caps apply. |

After the first match, opening drives and overtime use the same roll. Redrawing routes, substitutions
and kicks do not reroll an event. Dev Mode can preview each event between plays.
These values need full-run player balance testing before expanding items and
bowl effects; automated correctness checks do not establish difficulty balance.

## Bowl journey update

Implemented the practice opener, six-destination USA map, home-city journey and
a compact route ending at the chosen bowl. All six bowls have distinct muted
venues; Miami adds Heat/Hurricane, with route-specific Stadium Pulse, Ad Break,
Vegas Call and Police Investigation mixed into the original drive events.
Police distracts defenders without stopping offense, at most twice per game.
Existing Pro/Toilet special defenders remain final-bowl-only. Completion keys
and saved QB marks are preserved. See README for the venue/event table.

Additional unique bowl players, the introductions in priority 4, and full-run
balance testing remain unfinished.

## Completed foundation

Priority 1 preserves the original `Gridiron Run` save namespace and existing
completion records. Browser progress remains tied to the existing site address.
In-progress runs are not saved.

Priority 2 includes the formation/inspector layout, base-stat comparisons,
explicit roster and gear actions, shop Players/Gear tabs, purchase placement,
lab balance information and a named-loss ritual confirmation. Existing prices
and roster rules remain in place, including automatic release of a displaced
placeholder rookie and automatic starting placement of the first kicker.

The priority 2 build passed 47 real-screen roster checks, navigation checks,
keyboard confirmation/focus checks and rendered layout inspection at two window
sizes. See [README.md](README.md) for the game instructions and verification routes.

## Longer-term achievements

Build on the saved QB/bowl completion marks for the proposed **30 achievements**:
five QBs × six bowls, unlocking **15 players and 15 items**. This remains
longer-term work after the playable milestones above.

## Release direction

The recommended next playable milestone is priorities **1–4**, followed by
content in small batches and complete-run balance testing. Sound remains a
separate follow-up the developer intends to handle later. Steam onboarding and
store preparation are separate from this game-development sequence; this
roadmap does not promise a Steam release date.
