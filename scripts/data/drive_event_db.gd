class_name DriveEventDB
extends RefCounted

## Initial tuning values. Depth means completed matches, not drive number.
const NONE := ""
const OIL := "oil_spill"
const BOTTLES := "bottles"
const EXTRA_DEFENDER := "extra_defender"
const AURA := "aura_farm"
const ALL := [NONE, OIL, BOTTLES, EXTRA_DEFENDER, AURA]
const OIL_SPEED := 0.65
const BOTTLE_WARNING := 1.25
const BOTTLE_RADIUS := 2.0
const BOTTLE_STUN := 0.65
const BOTTLE_IMPACT := 0.35
const AURA_STATS := ["strength", "agility", "dexterity", "intelligence"]
const EVENTS := {
	NONE: {"name": "No drive event", "desc": "Ordinary football this drive."},
	OIL: {"name": "Oil Spill", "desc": "Dark patches slow BOTH teams to 65% speed. Avoid the marked turf."},
	BOTTLES: {"name": "Fans Throwing Bottles", "desc": "Up to 3 throws per play. Leave marked circles before impact (1.25s); hits stun for 0.65s. No throws during kicks."},
	EXTRA_DEFENDER: {"name": "Extra Defender", "desc": "A twelfth defender patrols a shallow zone. Find the space he leaves open."},
	AURA: {"name": "Aura Farm", "desc": "Your team gets +1 STR, AGI, DEX and INT, including substitutes. Normal caps apply."},
}


static func event_name(id: String) -> String:
	return String(EVENTS.get(id, EVENTS[NONE])["name"])


static func description(id: String) -> String:
	return String(EVENTS.get(id, EVENTS[NONE])["desc"])


static func chance(depth: int) -> float:
	return minf(0.65, 0.20 + 0.10 * maxi(0, depth))


static func roll(rng: RandomNumberGenerator, depth: int) -> String:
	if rng.randf() >= chance(depth):
		return NONE
	return ALL[rng.randi_range(1, ALL.size() - 1)]
