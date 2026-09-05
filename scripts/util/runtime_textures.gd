class_name RuntimeTextures
extends RefCounted
## Texture loading for content that may live outside the import pipeline:
## imported resources for res:// art, runtime-decoded images for user://
## (mod) art — mods are never imported — and a shared magenta placeholder
## for anything missing, because absent art is a normal state, not an error.

const PLACEHOLDER_SIZE := 32

static var _placeholder: Texture2D = null


## The texture at `path`, or null when it can't be provided. Callers decide
## whether null degrades to placeholder() or to skipping the visual.
static func from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path, "Texture2D"):
			return load(path)
		return null
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var image := Image.load_from_file(global_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


static func placeholder() -> Texture2D:
	if _placeholder == null:
		var image := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGB8)
		image.fill(Color(0.85, 0.2, 0.85))
		_placeholder = ImageTexture.create_from_image(image)
	return _placeholder
