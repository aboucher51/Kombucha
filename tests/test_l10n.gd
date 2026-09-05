extends GutTest


func test_key_hyphenates_the_id_only() -> void:
	assert_eq(L10n.key("item", "health_potion"), "item.health-potion.title")
	assert_eq(L10n.key("unit_type", "big_ship", "summary"), "unit_type.big-ship.summary")


func test_data_text_falls_back_to_the_defs_own_text() -> void:
	assert_eq(L10n.data_text("item", "nothing_here", "title", "As authored"), "As authored")


func test_translated_ui_key_is_returned() -> void:
	assert_eq(L10n.tr_or_fallback("ui.resume", "wrong"), "Resume")
