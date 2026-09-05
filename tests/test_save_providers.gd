extends GutTest
## The save_provider seam and the slot browser: providers are reached by
## group and has_method, an empty payload writes no key, a save is stamped
## and listed, a future schema is refused with a reason.

const SCRATCH_SAVES := "user://test_provider_saves"


class Provider extends Node:
	var key := "hero"
	var payload := {"hp": 7.0, "name": "Ada"}
	var restored := {}
	func save_key() -> String: return key
	func save_payload() -> Dictionary: return payload
	func restore_payload(data: Dictionary) -> void: restored = data


var _provider: Provider


func before_each() -> void:
	SaveManager.save_root = SCRATCH_SAVES
	_provider = Provider.new()
	_provider.add_to_group(SaveManager.PROVIDER_GROUP)
	add_child_autofree(_provider)


func after_each() -> void:
	for slot in ["slot_1", "slot_test", "extra_name"]:
		SaveManager.delete_save(slot)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT


func test_provider_slice_round_trips_through_a_slot() -> void:
	assert_eq(SaveManager.save_game("slot_test"), OK)
	_provider.restored = {}
	assert_eq(SaveManager.load_game("slot_test"), OK)
	assert_eq(_provider.restored, {"hp": 7.0, "name": "Ada"})


func test_empty_payload_writes_no_key() -> void:
	_provider.payload = {}
	var data := SaveManager.collect_save_data()
	assert_false(data.has("hero"))
	assert_true(data.has(SaveCompat.KEY), "still stamped")


func test_slot_meta_is_stamped_at_write() -> void:
	SaveManager.save_game("slot_test", {"label": "Chapter 2"})
	var meta := SaveManager.slot_meta("slot_test")
	assert_eq(meta.get("label"), "Chapter 2")
	assert_eq(meta.get("slot"), "slot_test")
	assert_gt(int(meta.get("saved_at", 0)), 0)
	assert_eq(SaveManager.slot_meta("slot_nothing"), {})


func test_list_slots_numbers_first_then_extras() -> void:
	SaveManager.save_game("extra_name")
	var slots := SaveManager.list_slots()
	assert_eq(slots.size(), SaveManager.SLOT_COUNT + 1)
	assert_eq(slots[0].get("slot"), "slot_1")
	assert_true(bool(slots[0].get("empty")))
	assert_eq(slots[-1].get("slot"), "extra_name")
	assert_false(bool(slots[-1].get("empty")))


func test_a_save_from_the_future_is_refused_with_a_reason() -> void:
	var data := SaveCompat.stamp({})
	data[SaveCompat.KEY]["schema"] = SaveCompat.SCHEMA + 1
	assert_false(SaveManager.apply_save_data(data))
	assert_string_contains(SaveManager.last_load_problem, "newer version")


func test_a_save_needing_a_missing_mod_is_refused_by_name() -> void:
	var result := SaveCompat.upgrade(SaveCompat.stamp({}, ["big_mod"]), [])
	assert_false(bool(result["ok"]))
	assert_string_contains(str(result["error"]), "big_mod")
	assert_true(bool(SaveCompat.upgrade(SaveCompat.stamp({}, ["big_mod"]), ["big_mod"])["ok"]))
