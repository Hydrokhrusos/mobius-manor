class_name Interactable
extends StaticBody3D
## A static thing you can press with E (light switches, buttons...).

var prompt := "Use"
var action: Callable = Callable()


func get_prompt() -> String:
	return prompt


func interact(_who) -> void:
	if action.is_valid():
		action.call()
