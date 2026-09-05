extends GutTest
## Line numbers for data findings: exact for syntax errors, best-effort for
## semantic messages, and never wrong-but-confident (0 means "no line").

const TEXT := '{\n\t"id": "potion",\n\t"effect": "freeze",\n\t"uses": 3\n}\n'


func test_syntax_error_reports_the_parsers_line() -> void:
	var finding := JsonLines.syntax_error('{\n\t"id": "x",\n\t"bad" 1\n}')
	assert_eq(int(finding.get("line", 0)), 3)
	assert_false(str(finding.get("message", "")).is_empty())


func test_valid_json_has_no_syntax_error() -> void:
	assert_eq(JsonLines.syntax_error(TEXT), {})


func test_semantic_message_lands_on_the_quoted_token() -> void:
	assert_eq(JsonLines.line_for_text(TEXT, "unknown effect kind 'freeze'"), 3)


func test_enumerated_legal_values_are_not_matched() -> void:
	# "have: a, b" lists every legal value; matching one would point at the
	# wrong line with total confidence.
	assert_eq(JsonLines.tokens_in("unknown kind 'x' (have: freeze, burn)"), ["x"])


func test_no_token_in_the_file_means_no_line() -> void:
	assert_eq(JsonLines.line_for_text(TEXT, "missing 'nothing_here'"), 0)
