extends Area2D

var order_id: String
var food_type: String
var customer_name: String = ""  # Added this property
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
		show_ready_indicator()

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

func show_ready_indicator():
	# Add visual effect to show food is ready
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", Color.YELLOW, 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

# Methods for the cooking station to set order information
func set_order_info(table_num: int, food_name: String, customer: String):
	order_id = str(table_num)  # Convert int to String to match your order_id type
	food_type = food_name
	customer_name = customer
	ready_for_collection = true
	show_ready_indicator()
	print("Food info set: ", food_name, " for ", customer, " at table ", table_num)

# Individual setter methods for flexibility
func set_order_id(id: int):
	order_id = str(id)

func set_food_type(type: String):
	food_type = type

func set_customer_name(name: String):
	customer_name = name

func set_ready(is_ready: bool):
	ready_for_collection = is_ready
	if ready_for_collection:
		show_ready_indicator()

func make_collectable():
	ready_for_collection = true
	show_ready_indicator()
