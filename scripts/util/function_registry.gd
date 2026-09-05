class_name FunctionRegistry
extends RefCounted
## A string-id -> Callable table, so data can name behaviour without calling
## code directly (data-driven content, scriptable hooks, mod entry points).
## Last registration wins (deliberate — a later layer may override an id).
## Missing id -> logged error + benign default, never a crash.

signal registered(id: String, source: String, overrode: bool)

var _functions: Dictionary = {}   # id -> Callable
var _sources: Dictionary = {}     # id -> source id that registered it


func register(id: String, callable: Callable, source: String = "") -> void:
	var overrode := _functions.has(id)
	if overrode and _sources.get(id) != source:
		print("FunctionRegistry: \"%s\" (from %s) overridden by %s" % [id, _sources.get(id, "?"), source])
	_functions[id] = callable
	_sources[id] = source
	registered.emit(id, source, overrode)


func has_function(id: String) -> bool:
	return _functions.has(id)


func get_callable(id: String) -> Callable:
	return _functions.get(id, Callable())


func source_of(id: String) -> String:
	return _sources.get(id, "")


func ids() -> Array:
	return _functions.keys()


## Invoke a registered function. Missing id logs an error and returns `default`.
func invoke(id: String, args: Array = [], default: Variant = null) -> Variant:
	var callable: Callable = _functions.get(id, Callable())
	if not callable.is_valid():
		push_error("FunctionRegistry: no function registered for id \"%s\" — returning default" % id)
		return default
	return callable.callv(args)
