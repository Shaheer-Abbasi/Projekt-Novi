class_name DialogueSequence
extends Resource
## A conversation written as plain text, one line of dialogue per line:
##
##     VOW: Arasaka headquarters. Quiet... too quiet.
##     INTERCOM: Welcome back, Vow.
##     Please proceed to the elevator.          <- no "NAME:" = the previous speaker keeps talking
##     # lines starting with # are notes to yourself and are never shown
##
## Create one via the Inspector (New DialogueSequence) or save it as a .tres file and reuse it.

@export_multiline var text: String = ""


func get_lines() -> Array:
	return parse(text)


func is_empty() -> bool:
	return text.strip_edges().is_empty()


## Turns the text above into [[speaker, line], ...]
static func parse(raw: String) -> Array:
	var out: Array = []
	var current := ""
	for line in raw.replace("\r", "").split("\n", false):
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		var idx := s.find(": ")
		if idx > 0 and idx <= 24:
			var prefix := s.substr(0, idx)
			if not ("[" in prefix or "]" in prefix):       # a BBCode tag is not a speaker name
				current = prefix.strip_edges()
				out.append([current, s.substr(idx + 2).strip_edges()])
				continue
		out.append([current, s])
	return out
