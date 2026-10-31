extends Node
## Skeleton for a headless driver: a dev-only mode the project runs from
## the command line (a sim, a balance gate, a linter, a bench). check.sh or
## CI can gate on it. Copy this file, rename it, register it as an autoload,
## and give it a flag:
##
##     godot4 --headless --path . -- --my-driver [args]
##
## Make it an autoload, not a `-s` script. Godot runs `-s` scripts without
## autoloads. So any class that names an autoload fails to compile there,
## with a misleading "identifier not found". A class cycle that only
## resolves once the autoloads register cannot compile at all. An autoload
## that frees itself when its flag is absent costs a normal run nothing.
##
## The exit code is the verdict: quit(0) on pass, quit(1) on a missed
## threshold. So a shell script can gate on it. Prove that the gate can
## fail before you trust it: restore the bug it guards against once, and
## watch it go red. A gate that cannot fail is worse than none, because
## people believe it.

const FLAG := "--my-driver"


func _ready() -> void:
	if not Cmdline.has_flag(FLAG):
		queue_free()
		return
	# Defer the run, so the rest of the autoloads (and the main scene)
	# finish their own _ready before the driver starts asking them questions.
	call_deferred("_run")


func _run() -> void:
	var ok := true
	# ... do the work. Print one `  ok    ...` / `  FAIL  ...` line per check,
	# in the shape check.sh prints. Set ok = false on any failure.
	get_tree().quit(0 if ok else 1)
