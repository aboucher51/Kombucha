class_name DataMerger
extends RefCounted
## Deep-merge semantics for layered dictionary data (config layering, content
## overrides, save migration, mod patches).
##
## Two modes:
##  - PLAIN  — override semantics with skip-if-default: null, "", 0/0.0, false
##             never overwrite. Lists never replace, they merge.
##  - PATCH  — explicit 0/false/""/null DO apply, and $-operations
##             ($replace, $remove, $set-null) are honored.

enum Mode { PLAIN, PATCH }

const OP_REPLACE := "$replace"
const OP_REMOVE := "$remove"
const OP_DELETE := "$delete"
const OP_SET_NULL := "$set-null"


static func is_default(value: Variant) -> bool:
	## "Not specified" per the skip-if-default rule. Empty lists/dicts are handled
	## by the list/dict merge rules themselves (merging nothing is a no-op).
	if value == null:
		return true
	match typeof(value):
		TYPE_STRING:
			return value == ""
		TYPE_INT:
			return value == 0
		TYPE_FLOAT:
			return value == 0.0
		TYPE_BOOL:
			return value == false
	return false


## Merge `incoming` over `base` in place. `base` must be a safely mutable copy.
static func merge_dict(base: Dictionary, incoming: Dictionary, mode: Mode = Mode.PLAIN) -> Dictionary:
	if mode == Mode.PATCH and incoming.get(OP_REPLACE, false) == true:
		base.clear()
		for key in incoming:
			if key != OP_REPLACE:
				base[key] = _copy(incoming[key])
		return base
	for key in incoming:
		var value: Variant = incoming[key]
		if mode == Mode.PLAIN and is_default(value):
			continue
		if mode == Mode.PATCH and value is Dictionary and value.get(OP_SET_NULL, false) == true:
			base[key] = null
			continue
		var existing: Variant = base.get(key)
		if existing is Dictionary and value is Dictionary:
			merge_dict(existing, value, mode)
		elif existing is Array and value is Array:
			merge_list(existing, value, mode)
		elif existing is Array and value is Dictionary and mode == Mode.PATCH:
			_patch_list(existing, value)
		else:
			base[key] = _copy(value)
	return base


## List merge: items with an `id` are matched by id and deep-merged, unmatched
## appended; strings are set-unioned (base order first); others append.
static func merge_list(base: Array, incoming: Array, mode: Mode = Mode.PLAIN) -> Array:
	for item in incoming:
		if item is Dictionary and item.has("id"):
			var match_idx := -1
			for i in base.size():
				if base[i] is Dictionary and base[i].get("id") == item["id"]:
					match_idx = i
					break
			if match_idx >= 0:
				merge_dict(base[match_idx], item, mode)
			else:
				base.append(_copy(item))
		elif item is String:
			if not base.has(item):
				base.append(item)
		else:
			base.append(_copy(item))
	return base


## PATCH mode: a list field patched with an object form:
##   { "$replace": [ ... ] }              — replace the list wholesale
##   { "$remove": ["id-or-value", ...] }  — remove entries (dicts by id, others by value)
## Both may be combined with a merge list via "$merge": [ ... ].
static func _patch_list(base: Array, ops: Dictionary) -> void:
	if ops.has(OP_REPLACE) and ops[OP_REPLACE] is Array:
		base.clear()
		for item in ops[OP_REPLACE]:
			base.append(_copy(item))
		return
	if ops.has(OP_REMOVE) and ops[OP_REMOVE] is Array:
		for target in ops[OP_REMOVE]:
			for i in range(base.size() - 1, -1, -1):
				var entry: Variant = base[i]
				if entry is Dictionary and entry.get("id") == target:
					base.remove_at(i)
				elif entry is String and entry == target:
					base.remove_at(i)
				elif typeof(entry) == typeof(target) and entry == target:
					base.remove_at(i)
	if ops.has("$merge") and ops["$merge"] is Array:
		merge_list(base, ops["$merge"], Mode.PATCH)


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
