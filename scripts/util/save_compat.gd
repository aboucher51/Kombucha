class_name SaveCompat
extends RefCounted
## Every save payload is stamped (schema, game version) and every load
## migrates before anything reads it. THE RULE: any change to what a
## provider writes bumps SCHEMA, adds a _to_N step, and freezes a golden
## old-format fixture in a test that must load forever — breaking an old
## save fails CI, not a player. Saves from the FUTURE refuse: guessing at
## unknown fields corrupts quietly.
##
## Mods: a project that loads mods stamps their ids too (`mod_ids`) and
## refuses a save whose mods are not loaded BY NAME. The check runs only
## when the payload carries a list, so a project without mods never sees it.

const SCHEMA := 1
const KEY := "_compat"


static func stamp(payload: Dictionary, mod_ids: Array = []) -> Dictionary:
	var meta := {"schema": SCHEMA, "game": VersionUtil.game()}
	if not mod_ids.is_empty():
		meta["mods"] = mod_ids
	payload[KEY] = meta
	return payload


## Migrate a payload to the current schema. Returns {ok, error, payload}.
## `loaded_mods` is the project's currently loaded mod ids (empty when the
## project has no mods).
static func upgrade(payload: Dictionary, loaded_mods: Array = []) -> Dictionary:
	var meta: Dictionary = payload.get(KEY, {})
	var schema := int(meta.get("schema", 0))
	if schema > SCHEMA:
		return {"ok": false, "error": "this save is from a newer version (schema %d, this game reads %d)"
			% [schema, SCHEMA], "payload": payload}
	for mod: Variant in Array(meta.get("mods", [])):
		var id := str(mod)
		if id != "" and not loaded_mods.has(id):
			return {"ok": false, "error": "this save needs the mod '%s', which is not loaded" % id,
				"payload": payload}
	var out := payload.duplicate(true)
	while schema < SCHEMA:
		schema += 1
		match "_to_%d" % schema:
			"_to_1":
				out = _to_1(out)
	return {"ok": true, "error": "", "payload": out}


## Schema 1: the first stamped format. Unstamped payloads are treated as it.
static func _to_1(payload: Dictionary) -> Dictionary:
	return payload
