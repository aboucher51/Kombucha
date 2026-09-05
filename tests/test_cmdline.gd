extends GutTest


func test_values_collects_every_pair_in_order() -> void:
	var args := PackedStringArray(["--scenario", "a.txt", "--seed", "1", "--scenario", "b.txt"])
	assert_eq(Cmdline.values_in(args, "--scenario"), ["a.txt", "b.txt"])
	assert_eq(Cmdline.values_in(args, "--seed"), ["1"])


func test_a_bare_switch_has_no_value_but_is_a_flag() -> void:
	var args := PackedStringArray(["--balance"])
	assert_eq(Cmdline.values_in(args, "--balance"), [])
	assert_true(Cmdline.has_flag_in(args, "--balance"))
	assert_false(Cmdline.has_flag_in(args, "--other"))


func test_a_trailing_name_with_no_value_is_not_a_pair() -> void:
	assert_eq(Cmdline.values_in(PackedStringArray(["--seed"]), "--seed"), [])
