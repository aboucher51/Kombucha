class_name Cmdline
extends RefCounted
## The post-`--` command line, for dev modes (`--scenario`, `--selftest`,
## `--balance` ...). Everything after the bare `--` is the project's via
## OS.get_cmdline_user_args(); the engine never sees it. The parsing takes
## the argument list explicitly so it is testable; the no-argument forms
## read the real command line.
##
## `has_flag` exists separately because a bare switch has no value:
## `values("--balance")` silently returns nothing for `--balance` on its
## own, which is not an error anywhere — the flag is ignored and the game
## boots and sits there.


## Every `--<name> <value>` pair's value, in order.
static func values(name: String) -> Array[String]:
	return values_in(OS.get_cmdline_user_args(), name)


## The first value, or "".
static func value(name: String) -> String:
	var found := values(name)
	return found[0] if not found.is_empty() else ""


## A bare switch, with or without a value after it.
static func has_flag(name: String) -> bool:
	return has_flag_in(OS.get_cmdline_user_args(), name)


static func values_in(args: PackedStringArray, name: String) -> Array[String]:
	var found: Array[String] = []
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			found.append(args[index + 1])
	return found


static func has_flag_in(args: PackedStringArray, name: String) -> bool:
	return args.has(name)
