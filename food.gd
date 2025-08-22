# Food.gd - Attach to food item scenes
extends Area2D

var order_id: String
var food_type: String
var ready_for_collection: bool = false

signal collected(collector)

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	# Add to ready_food group
	add_to_group("ready_food")
	
	# Connect area signals safely
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Set collision layers/masks for waiter detection
	collision_layer = 4  # Food layer
	collision_mask = 2   # Waiter layer
	
	# Visual indicator that food is ready
	if ready_for_collection:
		_show_ready_indicator()

func _on_body_entered(body):
	if not is_instance_valid(body):
		return
		
	if body.is_in_group("waiters") and ready_for_collection:
		# Automatically collect when waiter touches it
		collect_food(body)

func _on_body_exited(body):
	# This function can be used if you need to do something when bodies leave the area
	# For now, it's just here to prevent the error
	pass

func collect_food(collector):
	if not ready_for_collection or not is_instance_valid(collector):
		return
	
	print("Food collected: ", food_type, " by ", collector.name)
	
	# Give food to collector
	if collector.has_method("receive_food"):
		collector.receive_food(self)
	
	# Emit signal
	collected.emit(collector)
	
	# Remove from scene
	queue_free()

func _show_ready_indicator():
	# Add visual effect to show food is ready
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", Color.YELLOW, 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
