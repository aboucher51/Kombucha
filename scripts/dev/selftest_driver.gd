extends Node
## The FIXTURE's headless driver: exercises the dev_driver seed's shape
## (flag, self-free, deferred run, exit code as verdict) so the pattern is
## proven here. `--selftest` exits 0; `--selftest --selftest-fail` exits 1,
## which is how check.local.sh proves the gate can go red.

const FLAG := "--selftest"


func _ready() -> void:
	if not Cmdline.has_flag(FLAG):
		queue_free()
		return
	call_deferred("_run")


func _run() -> void:
	var ok := not Cmdline.has_flag("--selftest-fail")
	var autoloads_present := get_node_or_null("/root/DebugConsole") != null
	ok = ok and autoloads_present
	print("  %s  selftest driver (autoloads %s)" % ["ok  " if ok else "FAIL",
		"present" if autoloads_present else "MISSING"])
	get_tree().quit(0 if ok else 1)
