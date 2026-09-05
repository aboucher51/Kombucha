extends Node
## The FIXTURE's dev hooks: the smallest project extension that exercises
## every seam the shared console and harness offer, so a change to either
## is proven here before it is synced anywhere. See tools/seeds/dev_hooks.gd
## for the contract a real project starts from.
##
## The state is a static list of notes — global on purpose, because the
## sandbox hook exists to reset exactly this shape of thing between
## scenarios (scenarios/hooks_a.txt leaves one behind; hooks_b.txt proves it
## is gone).

static var notes: Array[String] = []


func sandbox() -> void:
	notes.clear()


func scenario_command(parts: PackedStringArray, _line: String) -> Variant:
	match parts[0]:
		"assert_note":
			if parts.size() < 2:
				return "ERROR: usage: assert_note <text>"
			var wanted := " ".join(parts.slice(1))
			if not notes.has(wanted):
				return "ERROR: no note '%s' (have: %s)" % [wanted, notes]
			return ""
	return null


func console_dispatch(handler: String, args: Dictionary) -> Variant:
	match handler:
		"busy":
			# Feeds the harness's `settle`: the main scene answers is_busy()
			# for this many frames.
			var main := get_tree().get_first_node_in_group("settle")
			if main == null or not main.has_method("set_busy"):
				return "ERROR: nothing in the 'settle' group to make busy"
			main.set_busy(int(args["frames"]))
			return "Busy for %d frames." % int(args["frames"])
		"note":
			notes.append(str(args["text"]))
			return "Noted."
		"notes":
			return "No notes." if notes.is_empty() else "\n".join(notes)
	return null
