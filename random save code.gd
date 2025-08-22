# KitchenStation.gd
extends StaticBody2D

@export var cooking_time: float = 5.0
@export var food_spawn_offset: Vector2 = Vector2(50, 0)  # Where food appears relative to station

var current_order = null
var is_cooking: bool = false
var cooked_food: Node2D = null
var cooking_timer: Timer

# Preload food scenes
@export var food_scenes: Dictionary = {
	"Margherita Pizza": preload("res://margherita_pizza.tscn"),
	"Lasagna Bolognese": preload("res://lasagna_bolognese.tscn"),
	"Fettuccine Alfredo": preload("res://fettuccine_alfredo.tscn")
}

signal food_ready(food_item, station)
signal food_collected(order_id, station)

func _ready():
	# Create cooking timer
	cooking_timer = Timer.new()
	cooking_timer.wait_time = cooking_time
	cooking_timer.one_shot = true
	cooking_timer.timeout.connect(_on_cooking_finished)
	add_child(cooking_timer)
	
	# Connect to OrderManager
	if OrderManager.has_signal("order_assigned"):
		OrderManager.order_assigned.connect(_on_order_assigned)

func _on_order_assigned(order_data, station_id):
	if station_id == get_instance_id():
		start_cooking(order_data)

func start_cooking(order_data):
	if is_cooking or cooked_food != null:
		print("Station busy!")
		return false
	
	current_order = order_data
	is_cooking = true
	cooking_timer.start()
	
	print("Started cooking: ", order_data.food_type, " - Time: ", cooking_time, "s")
	# You can add visual cooking effects here
	_show_cooking_indicator()
	
	return true

func _on_cooking_finished():
	is_cooking = false
	_spawn_food()
	_hide_cooking_indicator()
	
	print("Food ready: ", current_order.food_type)

func _spawn_food():
	if not current_order or not food_scenes.has(current_order.food_type):
		print("Error: No food scene for ", current_order.food_type)
		return
	
	# Spawn the food item
	var food_scene = food_scenes[current_order.food_type]
	cooked_food = food_scene.instantiate()
	
	# Set food properties
	cooked_food.order_id = current_order.id
	cooked_food.food_type = current_order.food_type
	cooked_food.position = global_position + food_spawn_offset
	
	# Add to scene
	get_tree().current_scene.add_child(cooked_food)
	
	# Make food collectable
	cooked_food.ready_for_collection = true
	
	# Signal that food is ready
	food_ready.emit(cooked_food, self)
	
	# Connect collection signal
	if cooked_food.has_signal("collected"):
		cooked_food.collected.connect(_on_food_collected)

func _on_food_collected(collector):
	print("Food collected by: ", collector.name)
	food_collected.emit(current_order.id, self)
	
	# Clear current order and food reference
	current_order = null
	cooked_food = null
	
	# Station is now available for new orders
	OrderManager.mark_station_available(get_instance_id())

func _show_cooking_indicator():
	# Add visual indication that food is cooking
	modulate = Color.ORANGE

func _hide_cooking_indicator():
	# Remove cooking indication
	modulate = Color.WHITE

# For manual interaction (if needed)
func interact_with_player():
	if cooked_food and cooked_food.ready_for_collection:
		# Player can manually collect food
		_on_food_collected(get_tree().get_first_node_in_group("player"))
		cooked_food.queue_free()
