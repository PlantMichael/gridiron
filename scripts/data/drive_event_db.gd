class_name DriveEventDB
extends RefCounted

## Initial tuning values. Depth means completed matches, not drive number.
const NONE := ""
const OIL := "oil_spill"
const BOTTLES := "bottles"
const EXTRA_DEFENDER := "extra_defender"
const AURA := "aura_farm"
const PULSE := "stadium_pulse"
const AD_BREAK := "ad_break"
const VEGAS := "vegas_call"
const POLICE := "police"
const GENERIC := [NONE, OIL, BOTTLES, EXTRA_DEFENDER, AURA]
const ALL := [NONE, OIL, BOTTLES, EXTRA_DEFENDER, AURA, PULSE, AD_BREAK, VEGAS, POLICE]
const OIL_SPEED := 0.65
const BOTTLE_WARNING := 1.25
const BOTTLE_RADIUS := 2.0
const BOTTLE_STUN := 0.65
const BOTTLE_IMPACT := 0.35
const AURA_STATS := ["strength", "agility", "dexterity", "intelligence"]
const EVENTS := {
	NONE: {"name": "No drive event", "desc": "Ordinary football this drive."},
	OIL: {"name": "Oil Spill", "desc": "Dark patches slow BOTH teams to 65% speed. Avoid the marked turf."},
	BOTTLES: {"name": "Angry Fans", "desc": "Up to 2 throws per drive. Leave marked circles before impact (1.25s); hits stun for 0.65s. No throws during kicks."},
	EXTRA_DEFENDER: {"name": "Extra Defender", "desc": "A twelfth defender patrols a shallow zone. Find the space he leaves open."},
	PULSE: {"name":"Stadium Pulse", "desc":"The team losing at the snap gets +1 to all stats this play. Ties give no boost."},
	AD_BREAK: {"name":"Ad Break", "desc":"Both teams have -1 to all stats for this drive."},
	VEGAS: {"name":"Vegas Call", "desc":"After 10 yards carrying the ball, the runner fumbles. Nearby teammates can recover."},
	POLICE: {"name":"Police Investigation", "desc":"Commotion distracts defenders after 2.2 live seconds. Once this drive, at most twice per game."},
	AURA: {"name": "Aura Farm", "desc": "Your team gets +1 STR, AGI, DEX and INT, including substitutes. Normal caps apply."},
}


static func event_name(id: String) -> String:
	return String(EVENTS.get(id, EVENTS[NONE])["name"])


static func description(id: String) -> String:
	return String(EVENTS.get(id, EVENTS[NONE])["desc"])


static func chance(depth: int) -> float:
	return minf(0.65, 0.20 + 0.10 * maxi(0, depth))


static func roll(rng: RandomNumberGenerator, depth: int, pool: Array = GENERIC) -> String:
	if rng.randf() >= chance(depth):
		return NONE
	var choices: Array = pool if pool.size() > 1 else GENERIC
	return String(choices[rng.randi_range(1, choices.size() - 1)])


static func pool_for_bowl(id: String) -> Array:
	var pool: Array = GENERIC.duplicate()
	for event in BowlDB.route(id).get("events",[]):
		if not pool.has(event):
			pool.append(event)
	return pool
