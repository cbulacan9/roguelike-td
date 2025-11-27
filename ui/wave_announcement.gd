# wave_announcement.gd
extends Control

@onready var announcement_label: Label = $CenterContainer/AnnouncementLabel

var countdown_active: bool = false
var countdown_time: float = 0.0

func _ready():
	# Connect to the spawner signals
	await get_tree().process_frame
	var spawner = _get_spawner()
	if spawner:
		spawner.wave_started.connect(_on_wave_started)
		spawner.wave_cleared.connect(_on_wave_cleared)
	else:
		push_warning("WaveAnnouncement: Could not find EnemySpawner")
	
	# Start hidden
	announcement_label.visible = false

func _process(delta: float):
	if countdown_active:
		countdown_time -= delta
		if countdown_time > 0:
			announcement_label.text = "Next wave in %d..." % ceili(countdown_time)
		else:
			countdown_active = false
			announcement_label.visible = false

func _get_spawner():
	var level = get_tree().get_first_node_in_group("level")
	if level and level.has_node("EnemySpawner"):
		return level.get_node("EnemySpawner")
	return null

func _on_wave_started(wave_number: int):
	countdown_active = false
	announcement_label.text = "Wave %d" % wave_number
	announcement_label.visible = true
	
	# Fade out after 2 seconds
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(announcement_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_hide_announcement)

func _on_wave_cleared(wave_number: int):
	# Get the delay from spawner
	var spawner = _get_spawner()
	var delay = 5.0
	if spawner:
		delay = spawner.delay_between_waves
	
	# Show countdown
	countdown_time = delay
	countdown_active = true
	announcement_label.modulate.a = 1.0
	announcement_label.visible = true

func _hide_announcement():
	announcement_label.visible = false
	announcement_label.modulate.a = 1.0
