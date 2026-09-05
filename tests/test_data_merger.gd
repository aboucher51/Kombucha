extends GutTest
## DataMerger's contract, ported from the hand-rolled suite it arrived with.


func test_plain_merge_skips_defaults() -> void:
	var base := {"a": 5, "b": true, "c": "keep", "n": 7}
	DataMerger.merge_dict(base, {"a": 0, "b": false, "c": "", "n": 9})
	assert_eq(base, {"a": 5, "b": true, "c": "keep", "n": 9})


func test_list_merge_rules() -> void:
	var lists := {"tags": ["x", "y"], "items": [{"id": "one", "v": 1}], "raw": [1]}
	DataMerger.merge_dict(lists, {"tags": ["y", "z"], "items": [{"id": "one", "w": 2}, {"id": "two"}], "raw": [2]})
	assert_eq(lists["tags"], ["x", "y", "z"], "string lists set-union in base order")
	assert_eq(lists["items"], [{"id": "one", "v": 1, "w": 2}, {"id": "two"}], "id lists deep-merge + append")
	assert_eq(lists["raw"], [1, 2], "non-id items append")


func test_nested_dicts_recurse() -> void:
	var nested := {"outer": {"keep": 1, "swap": 2}}
	DataMerger.merge_dict(nested, {"outer": {"swap": 3}})
	assert_eq(nested["outer"], {"keep": 1, "swap": 3})


func test_patch_mode_applies_explicit_defaults() -> void:
	var base := {"a": 5, "b": true}
	DataMerger.merge_dict(base, {"a": 0, "b": false}, DataMerger.Mode.PATCH)
	assert_eq(base, {"a": 0, "b": false})


func test_patch_replace_object() -> void:
	var obj := {"cfg": {"x": 1, "y": 2}}
	DataMerger.merge_dict(obj, {"cfg": {"$replace": true, "z": 3}}, DataMerger.Mode.PATCH)
	assert_eq(obj["cfg"], {"z": 3})


func test_patch_list_ops() -> void:
	var lists := {"tags": ["a", "b", "c"], "items": [{"id": "one"}, {"id": "two"}]}
	DataMerger.merge_dict(lists,
		{"tags": {"$remove": ["b"]}, "items": {"$replace": [{"id": "three"}]}},
		DataMerger.Mode.PATCH)
	assert_eq(lists["tags"], ["a", "c"], "$remove strips list entries")
	assert_eq(lists["items"], [{"id": "three"}], "$replace swaps list wholesale")


func test_patch_set_null() -> void:
	var base := {"a": 5}
	DataMerger.merge_dict(base, {"a": {"$set-null": true}}, DataMerger.Mode.PATCH)
	assert_eq(base, {"a": null})


func test_incoming_containers_are_copied() -> void:
	# A merged-in dict must be a deep copy — mutating the source afterwards
	# must not reach into the merged result.
	var source := {"nested": {"v": 1}}
	var base := {}
	DataMerger.merge_dict(base, source)
	source["nested"]["v"] = 99
	assert_eq(base["nested"]["v"], 1)
