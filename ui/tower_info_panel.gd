# tower_info_panel.gd
# Shows info about a selected placed tower with sell option
extends Panel

@onready var tower_name_label: Label = $MarginContainer/VBoxContainer/TowerNameLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var sell_button: Button = $MarginContainer/VBoxContainer/SellButton

var current_tower: Node3D = null

func _ready() -> void:
	# Start hidden
	visible = false
	
	# Connect to GameManager signals
	GameManager.tower_selection_changed.connect(_on_tower_selection_changed)
	
	# Connect sell button
	sell_button.pressed.connect(_on_sell_button_pressed)

func _on_tower_selection_changed(tower: Node3D) -> void:
	current_tower = tower
	
	if tower == null:
		visible = false
		return
	
	# Show the panel and update info
	visible = true
	_update_tower_info()

func _update_tower_info() -> void:
	if current_tower == null:
		return
	
	# Get tower data
	var tower_data: TowerData = null
	if "tower_data" in current_tower:
		tower_data = current_tower.tower_data
	
	if tower_data:
		tower_name_label.text = tower_data.display_name
		stats_label.text = "Damage: %.0f\nRange: %.0f\nSpeed: %.1f/s" % [
			tower_data.damage,
			tower_data.range_display,
			tower_data.attack_speed
		]
		
		var sell_value := tower_data.get_sell_value()
		sell_button.text = "Sell (+%d Gold)" % sell_value
	else:
		tower_name_label.text = "Unknown Tower"
		stats_label.text = "No stats available"
		sell_button.text = "Sell"

func _on_sell_button_pressed() -> void:
	if current_tower:
		GameManager.sell_selected_tower()
