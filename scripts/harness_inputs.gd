extends Control
## A FIXTURE scene for two harness verbs that reach input `click` cannot:
## `menu` picks an item from a MenuButton or an open PopupMenu (KOMBU-41),
## and `drag` from one named node to another runs Godot's own drag and drop
## (KOMBU-42). IceEngine needed both to author a mod by scripted clicks.
## Reached with `goto`, so the boot frame (a committed baseline) stays as is.

const EDIT_ITEMS := [
	{"text": "Rename", "id": 10},
	{"text": "Duplicate", "id": 11},
	{"separator": true},
	{"text": "Delete", "id": 12, "disabled": true, "tip": "Nothing is selected"},
	{"text": "Copy", "id": 13},
	{"text": "Copy", "id": 14},
]
const CONTEXT_ITEMS := [{"text": "Open", "id": 1}, {"text": "Close", "id": 2}]
## Items a player can drag, and whether the slot takes each one.
const DRAG_ITEMS := {"ItemApple": true, "ItemPear": true, "ItemRock": false}

## The last menu item picked, as "<menu>:<text>" (state key `menu_pick`).
var menu_pick := ""
## The last item dropped on the slot (state key `dropped`).
var dropped := ""
var _context_menu: PopupMenu
var _context_button: Button


func _ready() -> void:
	theme = UITheme.get_theme()
	add_to_group("state")
	var row := HBoxContainer.new()
	row.name = "MenuRow"
	row.position = Vector2(40, 40)
	add_child(row)
	var edit := MenuButton.new()
	edit.name = "EditMenu"
	edit.text = "Edit"
	edit.flat = false
	_fill(edit.get_popup(), EDIT_ITEMS)
	edit.get_popup().id_pressed.connect(_on_menu_id.bind("EditMenu", edit.get_popup()))
	row.add_child(edit)
	_context_button = Button.new()
	_context_button.name = "ContextButton"
	_context_button.text = "Open context menu"
	_context_button.pressed.connect(_open_context_menu)
	row.add_child(_context_button)
	_context_menu = PopupMenu.new()
	_context_menu.name = "ContextMenu"
	_fill(_context_menu, CONTEXT_ITEMS)
	_context_menu.id_pressed.connect(_on_menu_id.bind("ContextMenu", _context_menu))
	add_child(_context_menu)
	_build_drag_area()


static func _fill(popup: PopupMenu, items: Array) -> void:
	for item: Dictionary in items:
		if item.get("separator", false):
			popup.add_separator()
			continue
		popup.add_item(str(item["text"]), int(item["id"]))
		var index := popup.get_item_index(int(item["id"]))
		popup.set_item_disabled(index, bool(item.get("disabled", false)))
		popup.set_item_tooltip(index, str(item.get("tip", "")))


func _open_context_menu() -> void:
	var at := _context_button.get_global_rect()
	_context_menu.popup(Rect2i(Vector2i(at.position + Vector2(0, at.size.y)), Vector2i.ZERO))


func _on_menu_id(id: int, menu_name: String, popup: PopupMenu) -> void:
	menu_pick = "%s:%s" % [menu_name, popup.get_item_text(popup.get_item_index(id))]


func _build_drag_area() -> void:
	var list := VBoxContainer.new()
	list.name = "DragList"
	list.position = Vector2(40, 200)
	list.custom_minimum_size = Vector2(180, 0)
	add_child(list)
	for item_name: String in DRAG_ITEMS:
		var item := PanelContainer.new()
		item.name = item_name
		item.custom_minimum_size = Vector2(180, 40)
		item.set_drag_forwarding(_drag_data.bind(item_name), Callable(), Callable())
		var label := Label.new()
		label.text = item_name.trim_prefix("Item")
		item.add_child(label)
		list.add_child(item)
	var slot := PanelContainer.new()
	slot.name = "DropSlot"
	slot.position = Vector2(600, 220)
	slot.custom_minimum_size = Vector2(200, 100)
	slot.set_drag_forwarding(Callable(), _can_drop, _drop)
	var label := Label.new()
	label.name = "DropSlotLabel"
	label.text = "Drop here"
	slot.add_child(label)
	add_child(slot)


func _drag_data(_at: Vector2, item_name: String) -> Variant:
	return {"item": item_name}


func _can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and bool(DRAG_ITEMS.get((data as Dictionary).get("item", ""), false))


func _drop(_at: Vector2, data: Variant) -> void:
	dropped = str((data as Dictionary)["item"])
	var label := get_node("DropSlot/DropSlotLabel") as Label
	label.text = dropped.trim_prefix("Item")


func state_text() -> String:
	return "menu_pick=%s dropped=%s" % [menu_pick, dropped]


func assert_key(key: String, value: String) -> String:
	var actual := ""
	match key:
		"menu_pick": actual = menu_pick
		"dropped": actual = dropped
		_: return "ERROR: unknown key '%s'" % key
	if actual != value:
		return "ERROR: %s is '%s', expected '%s'" % [key, actual, value]
	return ""
