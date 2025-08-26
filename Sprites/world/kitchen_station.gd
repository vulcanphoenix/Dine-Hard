# CookingStation.gd
extends StaticBody2D

@export var min_cooking_time: float = 5.0
@export var max_cooking_time: float = 10.0
@export var food_spawn_offset: Vector2 = Vector2(50, 0)  # Where food appears relative to station
var current_order = null
var is_cooking: bool = false
var cooked_food: Area2D = null
var cooking_timer: Timer
var order_queue: Array = []  # Queue for incoming orders

# Preload food scenes - these should be Area2D scenes
@export var food_scenes: Dictionary = {
	"Margherita Pizza": preload("res://margherita_pizza.tscn"),
	"Lasagna Bolognese": preload("res://lasagna_bolognese.tscn"),
	"Fettuccine Alfredo": preload("res://fettuccine_alfredo.tscn")
}

signal food_ready(food_item: Area2D, station)
signal food_collected(order_id, station)

func _ready():
	# Add this cooking station to the cooking_stations group
	add_to_group("cooking_stations")
	
	# Create cooking timer
	cooking_timer = Timer.new()
	cooking_timer.one_shot = true
	cooking_timer.timeout.connect(_on_cooking_finished)
	add_child(cooking_timer)
	
	# Connect to OrderManager (keep this for backward compatibility)
	if OrderManager.has_signal("order_assigned"):
		OrderManager.order_assigned.connect(_on_order_assigned)

# NEW METHOD: Receive orders from the order terminal
func receive_orders(orders_array: Array):
	print("DEBUG: receive_orders called with ", orders_array.size(), " orders")
	print("DEBUG: Orders received: ", orders_array)
	
	# Add orders to our queue
	for order in orders_array:
		print("DEBUG: Processing order: ", order)
		print("DEBUG: Order type: ", typeof(order))
		
		# Handle CustomerOrder objects (your OrderManager uses custom class)
		var food_type = ""
		if typeof(order) == TYPE_OBJECT:
			# It's a CustomerOrder object
			food_type = order.food_item
			print("DEBUG: CustomerOrder food_item: ", food_type)
		elif typeof(order) == TYPE_DICTIONARY:
			# It's a dictionary with food_item
			food_type = order.get("food_item", "")
			print("DEBUG: Dictionary food_item: ", food_type)
		else:
			print("DEBUG: Unknown order format")
			continue
		
		print("DEBUG: Checking if can cook: ", food_type)
		print("DEBUG: Available food scenes: ", food_scenes.keys())
		
		if can_cook_food_type(food_type):
			order_queue.append(order)
			print("DEBUG: Added to queue: ", food_type)
		else:
			print("DEBUG: Cannot cook this food type: ", food_type)
	
	print("DEBUG: Queue size after adding orders: ", order_queue.size())
	
	# Start cooking if we're not busy
	process_order_queue()

# Check if this station can cook the specific food type
func can_cook_food_type(food_type: String) -> bool:
	return food_scenes.has(food_type)

# Process the order queue
func process_order_queue():
	print("DEBUG: process_order_queue called")
	print("DEBUG: Queue size: ", order_queue.size())
	print("DEBUG: Is cooking: ", is_cooking)
	print("DEBUG: Cooked food exists: ", cooked_food != null)
	
	if order_queue.size() > 0 and not is_cooking and cooked_food == null:
		var next_order = order_queue.pop_front()
		print("DEBUG: Starting to cook next order: ", next_order)
		start_cooking(next_order)
	else:
		print("DEBUG: Cannot process queue - busy or no orders")

func _on_order_assigned(order_data, station_id):
	if station_id == get_instance_id():
		start_cooking(order_data)

func start_cooking(order_data):
	if is_cooking or cooked_food != null:
		print("Station busy!")
		return false
	
	current_order = order_data
	is_cooking = true
	
	# Set random cooking time between min and max
	var random_cooking_time = randf_range(min_cooking_time, max_cooking_time)
	cooking_timer.wait_time = random_cooking_time
	cooking_timer.start()
	
	# Get food name from CustomerOrder object
	var food_name = ""
	if typeof(order_data) == TYPE_OBJECT:
		food_name = order_data.food_item
	elif typeof(order_data) == TYPE_DICTIONARY:
		food_name = order_data.get("food_item", "Unknown")
	
	print("Started cooking: ", food_name, " - Time: ", "%.1f" % random_cooking_time, "s")
	print("DEBUG: Timer started, wait_time: ", cooking_timer.wait_time)
	print("DEBUG: Order data: ", order_data)
	
	# You can add visual cooking effects here
	show_cooking_indicator()
	
	return true

func _on_cooking_finished():
	print("DEBUG: Cooking timer finished!")
	is_cooking = false
	spawn_food()
	hide_cooking_indicator()
	
	# Get food name for display
	var food_name = ""
	if current_order:
		if typeof(current_order) == TYPE_OBJECT:
			food_name = current_order.food_item
		elif typeof(current_order) == TYPE_DICTIONARY:
			food_name = current_order.get("food_item", "Unknown")
	
	print("Food ready: ", food_name if food_name != "" else "No current order")
	
	# Process next order in queue if available
	process_order_queue()

func spawn_food():
	print("DEBUG: spawn_food() called")
	print("DEBUG: current_order exists: ", current_order != null)
	
	if not current_order:
		print("ERROR: No current order!")
		return
	
	# Get food name from CustomerOrder object
	var food_name = ""
	if typeof(current_order) == TYPE_OBJECT:
		food_name = current_order.food_item
	elif typeof(current_order) == TYPE_DICTIONARY:
		food_name = current_order.get("food_item", "")
	
	print("DEBUG: Looking for food scene for: ", food_name)
	print("DEBUG: Available food scenes: ", food_scenes.keys())
	
	if not food_scenes.has(food_name):
		print("ERROR: No food scene for ", food_name)
		print("Available food types: ", food_scenes.keys())
		return
	
	print("DEBUG: Creating food instance...")
	
	# Spawn the food item (Area2D)
	var food_scene = food_scenes[food_name]
	
	if not food_scene:
		print("ERROR: Food scene is null for ", food_name)
		return
	
	cooked_food = food_scene.instantiate() as Area2D
	
	if not cooked_food:
		print("ERROR: Failed to instantiate food scene as Area2D!")
		return
	
	print("DEBUG: Food instantiated successfully as Area2D")
	print("DEBUG: Food node type: ", cooked_food.get_class())
	print("DEBUG: Food node name: ", cooked_food.name)
	
	# Set food properties - handle CustomerOrder object
	if typeof(current_order) == TYPE_OBJECT:
		# CustomerOrder object - your OrderManager uses a custom class
		if cooked_food.has_method("set_order_info"):
			cooked_food.set_order_info(current_order.table_number, current_order.food_item, current_order.customer_name)
			print("DEBUG: Used set_order_info method")
		else:
			# Try to set properties if they exist in the script
			if cooked_food.has_method("set_order_id"):
				cooked_food.set_order_id(current_order.table_number)
			elif cooked_food.get("order_id") != null:
				cooked_food.order_id = str(current_order.table_number)
			else:
				print("DEBUG: Food script doesn't have order_id property")
			
			if cooked_food.has_method("set_food_type"):
				cooked_food.set_food_type(current_order.food_item)
			elif cooked_food.get("food_type") != null:
				cooked_food.food_type = current_order.food_item
			else:
				print("DEBUG: Food script doesn't have food_type property")
			
			if cooked_food.has_method("set_customer_name"):
				cooked_food.set_customer_name(current_order.customer_name)
			elif cooked_food.get("customer_name") != null:
				cooked_food.customer_name = current_order.customer_name
			else:
				print("DEBUG: Food script doesn't have customer_name property")
			
			print("DEBUG: Set order properties where available")
	
	# Position the food near the cooking station
	cooked_food.global_position = global_position + food_spawn_offset
	
	print("DEBUG: Adding Area2D food to scene at position: ", cooked_food.global_position)
	
	# Add to scene
	get_tree().current_scene.add_child(cooked_food)
	
	# Make food collectable - try different approaches safely
	if cooked_food.has_method("set_ready"):
		cooked_food.set_ready(true)
		print("DEBUG: Used set_ready method")
	elif cooked_food.has_method("make_collectable"):
		cooked_food.make_collectable()
		print("DEBUG: Used make_collectable method")
	elif cooked_food.get("ready_for_collection") != null:
		cooked_food.ready_for_collection = true
		print("DEBUG: Set ready_for_collection property")
	else:
		print("DEBUG: Food script doesn't have collection properties, assuming it's ready")
	
	# Signal that food is ready
	food_ready.emit(cooked_food, self)
	
	print("DEBUG: Area2D food spawned successfully: ", food_name)
	print("DEBUG: Food position: ", cooked_food.global_position)
	print("DEBUG: Food visible: ", cooked_food.visible)
	
	# Connect collection signal - try different signal names
	var collection_signals = ["collected", "picked_up", "grabbed", "taken", "body_entered"]
	
	for signal_name in collection_signals:
		if cooked_food.has_signal(signal_name):
			# Different connection methods depending on signal
			if signal_name == "body_entered":
				cooked_food.body_entered.connect(_on_food_area_entered)
			else:
				cooked_food.connect(signal_name, _on_food_collected)
			print("DEBUG: Connected to ", signal_name, " signal")
			break

# Handle Area2D body_entered signal
func _on_food_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		_on_food_collected(body)

func _on_food_collected(collector):
	print("Food collected by: ", collector.name)
	
	# Get order ID safely from CustomerOrder
	var order_identifier = ""
	if current_order and typeof(current_order) == TYPE_OBJECT:
		order_identifier = str(current_order.table_number)
	elif current_order and typeof(current_order) == TYPE_DICTIONARY:
		order_identifier = str(current_order.get("table_number", current_order.get("id", "unknown")))
	
	food_collected.emit(order_identifier, self)
	
	# Clear current order and food reference
	current_order = null
	cooked_food = null
	
	# Station is now available for new orders
	if OrderManager.has_method("mark_station_available"):
		OrderManager.mark_station_available(get_instance_id())

func show_cooking_indicator():
	# Add visual indication that food is cooking
	modulate = Color.ORANGE

func hide_cooking_indicator():
	# Remove cooking indication
	modulate = Color.WHITE

# For manual interaction (if needed)
func interact_with_player():
	if cooked_food and cooked_food.ready_for_collection:
		# Player can manually collect food
		_on_food_collected(get_tree().get_first_node_in_group("player"))
		cooked_food.queue_free()

# Get station status for debugging
func get_status() -> String:
	var status = "Station Status:\n"
	status += "Cooking: " + str(is_cooking) + "\n"
	status += "Food Ready: " + str(cooked_food != null) + "\n"
	status += "Queue Size: " + str(order_queue.size())
	return status
