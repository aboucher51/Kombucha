class_name L10n
extends RefCounted
## Derives translation keys for tr(), namespaced by entity type so ids that
## collide across categories (e.g. an item and a status both named "insight")
## can't collide on the same translation key. Hyphenates THE ID ONLY — type
## and field keep their underscores:
##
##     L10n.key("item", "health_potion")  # -> "item.health-potion.title"


static func key(type: String, id: String, field: String = "title") -> String:
	return "%s.%s.%s" % [type, id.replace("_", "-"), field]


## Translates translation_key, falling back to fallback_text when no
## translation exists for it — TranslationServer.translate() returns the
## key unchanged when untranslated, which is how the fallback is detected.
static func tr_or_fallback(translation_key: String, fallback_text: String) -> String:
	var result := TranslationServer.translate(translation_key)
	return result if result != translation_key else fallback_text


## Content text: the derived key for a JSON def's field, with the def's own
## text as the fallback, so an untranslated entry reads as authored.
static func data_text(type: String, id: String, field: String, fallback_text: String) -> String:
	return tr_or_fallback(key(type, id, field), fallback_text)
