# tower_data.gd
# Resource class for defining tower types
class_name TowerData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 100
@export var scene: PackedScene
@export var icon: Texture2D  # Optional icon for UI
@export var preview_color: Color = Color(0.5, 0.5, 1.0, 0.5)

# Selling
@export_group("Economy")
@export var sell_ratio: float = 0.75  # Percentage of cost returned when selling

func get_sell_value() -> int:
	return int(cost * sell_ratio)

# Stats for display (actual stats come from the tower scene)
@export_group("Display Stats")
@export var damage: float = 10.0
@export var range_display: float = 5.0
@export var attack_speed: float = 1.0
