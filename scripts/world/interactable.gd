class_name Interactable
extends Node3D
## Something the hero can click and walk up to: doors, braziers, portals.
## Clicking makes the hero walk over; on arrival `interacted` fires.

signal interacted(node: Interactable)

var display_name: String = ""
var enabled: bool = true
var _tag: Label3D


func _ready() -> void:
	add_to_group(&"npcs")  # Same click-and-walk handling as NPCs.
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.text = display_name
	_tag.position.y = 2.6
	_tag.font_size = 30
	_tag.pixel_size = 0.004
	_tag.outline_size = 8
	_tag.modulate = Color("6ec3f0")
	_tag.outline_modulate = Color(0.12, 0.13, 0.16, 0.9)
	add_child(_tag)


func set_label(text: String) -> void:
	display_name = text
	if _tag:
		_tag.text = text


func interact() -> void:
	if enabled:
		interacted.emit(self)
