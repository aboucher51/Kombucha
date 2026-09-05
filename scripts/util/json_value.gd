class_name JsonValue
extends RefCounted
## Reading values that came out of JSON, where the type is whatever the
## author wrote.
##
## Def fields are arbitrary JSON, so the ordinary casts are traps: GDScript's
## `bool()` REFUSES a String, and `String()` refuses a bool — and an absent
## field arrives as `false`, which is the common case. Both directions have
## already cost a session (CLAUDE.md keeps the scars), so the type-aware
## answers live here rather than being re-derived per call site.


## Is this value set, in the sense JSON data means it?
##
## `fallback` answers only for ABSENT (null); everything else has a real
## answer. An unrecognised type counts as set, because the author wrote
## something there.
static func truthy(value: Variant, fallback: bool = false) -> bool:
	match typeof(value):
		TYPE_NIL:
			return fallback
		TYPE_BOOL:
			return value
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value) != ""
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_DICTIONARY:
			return not Dictionary(value).is_empty()
		TYPE_ARRAY:
			return not Array(value).is_empty()
	return true


## The same question for a value a HUMAN typed into a form, where the word
## "false" means false rather than "a non-empty string".
##
## Deliberately separate from truthy(): the sim must keep reading
## `"stealth": "submerged"` as set, and a form field holding the text
## "false" must not. One function trying to serve both would have to pick,
## and either choice is wrong somewhere.
static func typed_truthy(value: Variant, fallback: bool = false) -> bool:
	if value is String and String(value).to_lower() == "false":
		return false
	return truthy(value, fallback)
