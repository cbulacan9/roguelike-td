extends Node

const SYNTAX_GUIDE = """
Godot 4.3 GDScript Syntax:
- Exports: @export var name := value
- Signals: signal name(param: Type)
- Onready: @onready var node = $NodePath
- Types: var array: Array[Type] = []
- Await: await signal_or_timer
- Physics: extends CharacterBody3D, move_and_slide()
"""

static func get_context_for_prompt(base_prompt: String) -> String:
	return SYNTAX_GUIDE + "\n\n" + base_prompt
