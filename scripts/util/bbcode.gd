class_name BBCode
extends RefCounted
## Putting text somebody else wrote into a RichTextLabel.
##
## Any string interpolated into a `bbcode_enabled` label is MARKUP, not
## text: `[img]`, `[url]`, `[color]` and `[font_size=999]` are all live.
## Every string the engine builds is safe by construction; the ones a
## PERSON wrote are not — a save slot's name, a chat line, a mod's title.
##
## `escape()` is the answer for both. Godot's own escape for an opening
## bracket is the `[lb]` tag.


## Text that will be interpolated into a bbcode label, made inert.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


## Text that arrived from somebody else's machine: made inert, stripped of
## the control characters that could forge extra lines in a log or a
## console, collapsed to one line, and clamped.
##
## Clamped HERE rather than at the input box, because the sender's client
## is the attacker's client — a limit enforced only while typing is not
## enforced at all. A "one line" message costs nothing to send at 10 MB.
static func sanitise(text: String, limit: int) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		# space and up, minus DEL; newlines and tabs become spaces
		if c == "\n" or c == "\r" or c == "\t":
			out += " "
		elif c.unicode_at(0) >= 32 and c.unicode_at(0) != 127:
			out += c
		if out.length() >= limit:
			break
	return escape(out.strip_edges()).left(limit)
