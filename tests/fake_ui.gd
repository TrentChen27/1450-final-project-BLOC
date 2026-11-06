extends RefCounted
signal debug_requested(action: String, card: int, player: int, points: int)
var game
var handler := Callable()
var pause_after := {"button_pressed": false}
var answers: Array = []
var questions: Array[String] = []
var logs: Array[String] = []
var result := ""
func refresh() -> void: pass
func log_event(text: String) -> void: logs.append(text)
func show_result(text: String) -> void: result = text
func choose(_value) -> void: pass
func ask(question: String, options: Array):
	questions.append(question)
	if handler.is_valid():
		return handler.call(question, options)
	if answers.is_empty():
		return options[0].id
	var answer = answers.pop_front()
	if answer is Callable:
		return answer.call(options)
	for option in options:
		if typeof(option.id) == typeof(answer) and option.id == answer:
			return answer
	assert(false, "Invalid scripted answer %s for %s" % [answer, question])
	return null
