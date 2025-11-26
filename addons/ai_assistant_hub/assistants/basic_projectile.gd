extends Node3D

@export var speed: float = 20.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0

var target: Node3D = null
var velocity: Vector3

func _ready() -> void:
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func set_target(new_target: Node3D) -> void:
	target = new_target
	if target:
		# Calculate initial direction
		velocity = (target.global_position - global_position).normalized() * speed

func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		# Homing behavior (optional - remove for straight shots)
		var direction = (target.global_position - global_position).normalized()
		velocity = velocity.lerp(direction * speed, 0.05)

	# Move projectile
	global_position += velocity * delta

	# Rotate to face direction of travel
	if velocity.length() > 0:
		look_at(global_position + velocity)

func _on_area_entered(area: Area3D) -> void:
	var body = area.get_parent()

	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()  # Destroy projectile on hit
