extends Node
## Skeleton for a headless DRIVER: a dev-only mode the project runs from the
## command line (a sim, a balance gate, a linter, a bench) that check.sh or
## CI can gate on. Copy, rename, register as an autoload, and give it a flag:
##
##     godot4 --headless --path . -- --my-driver [args]
##
## Why an autoload and not a `-s` script: `-s` scripts run WITHOUT autoloads,
## so any class that names one fails to compile there with a misleading
## "identifier not found", and a class cycle that only resolves once the
## autoloads are registered cannot compile at all. An autoload that frees
## itself when its flag is absent costs a normal run nothing.
##
## The exit code IS the verdict: quit(0) on pass, quit(1) on a missed
## threshold, so a shell script can gate on it. And a gate must be proven
## able to fail: restore the bug it guards against once, watch it go red,
## then trust it. A gate that cannot fail is worse than none, because it
## gets believed.

const FLAG := "--my-driver"


func _ready() -> void:
	if not Cmdline.has_flag(FLAG):
		queue_free()
		return
	# Deferred so the rest of the autoloads (and the main scene) finish
	# their own _ready before the driver starts asking them questions.
	call_deferred("_run")


func _run() -> void:
	var ok := true
	# ... do the work; print one `  ok    ...` / `  FAIL  ...` line per check
	# in the shape check.sh prints, and set ok = false on any failure.
	get_tree().quit(0 if ok else 1)
