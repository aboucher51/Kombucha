class_name JsonLines
extends RefCounted
## Line numbers for diagnostics. `JSON.parse()` throws position away the
## moment it succeeds, so a semantic complaint ("unknown effect kind") has
## a file but no line — which is the difference between a mod author
## finding the problem in seconds and hunting for it.
##
## Two tiers, both best-effort and neither ever wrong-but-confident:
##
## - **Syntax errors** get an EXACT line, straight from Godot's parser.
## - **Semantic findings** get a line by looking for the offending token
##   the message already quotes. Load-report messages here consistently
##   name what upset them (`unknown effect kind 'freeze'`), so pulling the
##   quoted token out and finding it in the file lands on the right line
##   without every warn() call site having to carry a path.
##
## A lookup that fails returns 0, meaning "no line" — a finding without a
## line is still useful, a finding with the WRONG line is worse than none.

## {"line": int, "message": String} when the text does not parse, {} when
## it does. The line is 1-based, as an editor counts them: JSON's
## get_error_line() is 0-based (probed on 4.7: an error on the first line
## reports 0), which the original of this helper missed, so its linter
## pointed one line early.
static func syntax_error(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) == OK:
		return {}
	return {"line": json.get_error_line() + 1, "message": json.get_error_message()}


## The quoted tokens in a load-report message, in the order they appear.
## Both quote styles, because the messages use both (`unknown trigger 'x'`
## and `missing "id"`).
static func tokens_in(message: String) -> Array[String]:
	var found: Array[String] = []
	for pattern: String in ["'([^']+)'", "\"([^\"]+)\""]:
		var regex := RegEx.new()
		if regex.compile(pattern) != OK:
			continue
		for hit in regex.search_all(message):
			var token := hit.get_string(1)
			# "have: damage, heal, …" lists every legal value; matching one
			# of those would point at the wrong line with total confidence.
			if not token.is_empty() and not token.contains(", ") and not found.has(token):
				found.append(token)
	return found


## First line of `text` that mentions any of `tokens` as a JSON string,
## or 0 when none of them appear. Tokens are tried in order, so the most
## specific one the message named wins.
static func line_of(text: String, tokens: Array[String]) -> int:
	if tokens.is_empty():
		return 0
	var lines := text.split("\n")
	for token in tokens:
		var quoted := "\"%s\"" % token
		for i in lines.size():
			if lines[i].contains(quoted):
				return i + 1
	# Nothing matched as a JSON string; accept a bare mention rather than
	# giving up, since some messages quote a value that is not a string.
	for token in tokens:
		for i in lines.size():
			if lines[i].contains(token):
				return i + 1
	return 0


## The whole job for one finding: read the file, resolve a line from the
## message. Returns 0 when the file cannot be read — a missing file is
## itself a finding, reported by the caller.
static func line_for(path: String, message: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return line_for_text(FileAccess.get_file_as_string(path), message)


## The same over text already in hand (a test, or a file read once for
## several findings).
static func line_for_text(text: String, message: String) -> int:
	return line_of(text, tokens_in(message))
