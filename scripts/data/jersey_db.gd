class_name JerseyDB
extends RefCounted

## Jersey colours. Your team always wears BLUE - the original body art in
## assets/players/<view>/. Every other colour is a full copy of that art cut
## from its own sprite sheets, fitted to
## the blue bodies pixel for pixel, in assets/players/<colour>/<view>/.
## The opponent draws one of COLORS at random each match (MatchSim.setup).
##
## Coloured bodies share the blue canvases/rigs. Civilian palettes use the
## same colour names in assets/sidelines/<colour>/<view>/.

const BLUE := ""
const COLORS := ["green", "red", "black", "brown", "orange", "purple"]

## Desaturated presentation accents keep the field quieter than the uniforms.
const SCORE_COLORS := {
	BLUE: Color("6689a5"), "red": Color("ad7166"), "green": Color("7d9a71"),
	"black": Color("8d979e"), "brown": Color("a08065"),
	"orange": Color("c69360"), "purple": Color("9e7fb2"),
}
const ENDZONE_COLORS := {
	BLUE: Color("303e46"), "red": Color("483a36"), "green": Color("374537"),
	"black": Color("303336"), "brown": Color("40382f"),
	"orange": Color("4b3e30"), "purple": Color("40354a"),
}


static func score_color(jersey: String) -> Color:
	return SCORE_COLORS.get(jersey, SCORE_COLORS[BLUE])


static func endzone_color(jersey: String) -> Color:
	return ENDZONE_COLORS.get(jersey, ENDZONE_COLORS[BLUE])


## A random opponent colour, or blue if no others exist yet.
static func random_opponent() -> String:
	return BLUE if COLORS.is_empty() else String(COLORS.pick_random())
