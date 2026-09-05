class_name VersionUtil
extends RefCounted
## Dotted-version arithmetic, shared by save migration and mod requirements.
## Deliberately minimal: minimum-version checks answer nearly every real
## compatibility question at a fraction of a range-grammar's surface.


static func game() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func compare(a: String, b: String) -> int:
	## -1, 0, 1 — missing components read as 0, junk components as 0, so a
	## malformed version compares LOW rather than crashing a load path.
	var pa := a.strip_edges().split(".")
	var pb := b.strip_edges().split(".")
	for i in maxi(pa.size(), pb.size()):
		var na := int(pa[i]) if i < pa.size() and pa[i].is_valid_int() else 0
		var nb := int(pb[i]) if i < pb.size() and pb[i].is_valid_int() else 0
		if na != nb:
			return -1 if na < nb else 1
	return 0


static func at_least(have: String, need: String) -> bool:
	return compare(have, need) >= 0
