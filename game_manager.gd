# game_manager.gd
extends Node

# Signals for UI to listen to
signal resource_changed(resource_type: String, amount: int)
signal wave_changed(wave_number: int)
signal wave_cleared(wave_number: int)
signal game_won
signal game_lost
signal tower_selected(tower_data: TowerData)
signal tower_sold(tower: Node3D, refund_amount: int)
signal tower_selection_changed(tower: Node3D)  # For clicking on placed towers

# Game resources
var gold: int = 500:
	set(value):
		gold = value
		resource_changed.emit("gold", gold)

var lives: int = 20:
	set(value):
		lives = value
		resource_changed.emit("lives", lives)

var current_wave: int = 0:
	set(value):
		current_wave = value
		wave_changed.emit(current_wave)

var is_game_over: bool = false

# Tower type definitions
var tower_types: Array[TowerData] = []
var selected_tower: TowerData = null

# Currently selected placed tower (for selling/upgrading)
var selected_placed_tower: Node3D = null

func _ready() -> void:
	print("GameManager loaded")
	_init_tower_types()

func _init_tower_types() -> void:
	# Basic Tower
	var basic := TowerData.new()
	basic.id = "basic"
	basic.display_name = "Basic Tower"
	basic.description = "A simple tower with balanced stats."
	basic.cost = 100
	basic.scene = preload("res://objects/basic_tower.tscn")
	basic.preview_color = Color(0.5, 0.8, 0.5, 0.5)
	basic.damage = 25.0
	basic.range_display = 10.0
	basic.attack_speed = 1.0
	tower_types.append(basic)
	
	# Wizard Tower
	var wizard := TowerData.new()
	wizard.id = "wizard"
	wizard.display_name = "Wizard Tower"
	wizard.description = "A magical tower with powerful spells."
	wizard.cost = 200
	wizard.scene = preload("res://objects/wizard_tower.tscn")
	wizard.preview_color = Color(0.6, 0.4, 0.9, 0.5)
	wizard.damage = 40.0
	wizard.range_display = 12.0
	wizard.attack_speed = 0.8
	tower_types.append(wizard)
	
	# Set default selection
	if tower_types.size() > 0:
		selected_tower = tower_types[0]

# Tower selection
func select_tower(tower_id: String) -> void:
	for tower_data in tower_types:
		if tower_data.id == tower_id:
			selected_tower = tower_data
			tower_selected.emit(tower_data)
			print("Selected tower: ", tower_data.display_name)
			return
	push_warning("Tower type not found: " + tower_id)

func get_tower_data(tower_id: String) -> TowerData:
	for tower_data in tower_types:
		if tower_data.id == tower_id:
			return tower_data
	return null

func can_afford_selected_tower() -> bool:
	if selected_tower == null:
		return false
	return gold >= selected_tower.cost

# Placed tower selection (for selling/upgrading)
func select_placed_tower(tower: Node3D) -> void:
	# Deselect previous tower
	if selected_placed_tower and selected_placed_tower != tower:
		if selected_placed_tower.has_method("deselect"):
			selected_placed_tower.deselect()
	
	selected_placed_tower = tower
	
	if tower and tower.has_method("select"):
		tower.select()
	
	tower_selection_changed.emit(tower)

func deselect_placed_tower() -> void:
	if selected_placed_tower and selected_placed_tower.has_method("deselect"):
		selected_placed_tower.deselect()
	selected_placed_tower = null
	tower_selection_changed.emit(null)

func sell_selected_tower() -> bool:
	if selected_placed_tower == null:
		return false
	
	var tower := selected_placed_tower
	var refund_amount := 0
	
	if tower.has_method("get_sell_value"):
		refund_amount = tower.get_sell_value()
	
	# Store reference before clearing selection
	var sold_tower := tower
	
	# Deselect first
	deselect_placed_tower()
	
	# Add refund
	add_gold(refund_amount)
	
	# Emit signal before destroying (so UI can respond)
	tower_sold.emit(sold_tower, refund_amount)
	
	# The actual tower removal and grid freeing will be handled by TowerPlacementManager
	# since it has access to the map_grid
	return true

# Helper methods for modifying resources
func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func lose_life() -> void:
	lives -= 1
	if lives <= 0:
		game_over()

func game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	print("Game Over!")
	game_lost.emit()

func victory() -> void:
	if is_game_over:
		return
	is_game_over = true
	print("Victory!")
	game_won.emit()

func reset_game() -> void:
	gold = 500
	lives = 20
	current_wave = 0
	is_game_over = false
	if tower_types.size() > 0:
		selected_tower = tower_types[0]
