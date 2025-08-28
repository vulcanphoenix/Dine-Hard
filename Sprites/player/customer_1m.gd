extends CharacterBody2D
# Restaurant Customer NPC with Automatic Italian Food Selection
# This script goes on the root node of the NPC scene file

@export var customer_name: String = "Mr. Anderson"
@export var dialogue_lines: Array[String] = [
	"Excuse me, waiter! Could I get some service?",
	"Table for one please (Walk to the table and interact with it to seat the customer.)",
]

# Food ordering system - Italian themed options
@export var available_foods: Array[String] = [
	"Margherita Pizza", 
	"Fettuccine Alfredo",
	"Lasagna Bolognese",
]

# Interaction variables
var player_in_range = false
var current_dialogue_index = 0
var is_talking = false
var has_ordered = false
var ready_for_seating = false
var assigned_table = null
var is_walking_to_table = false
var is_walking_to_payment = false
var target_position = Vector2.ZERO
var walking_speed = 160.0

# Payment system variables
var payment_point = null
var has_paid = false

# Ordering system states
enum OrderingState {
	INITIAL_GREETING,
	SEATED_SETTLING,
	SEATED_WAITING,
	SHOWING_MENU,
	WAITING_FOR_ORDER,
	ORDER_COMPLETE,
	EATING,
	FINISHED,
	WALKING_TO_PAYMENT,
	AT_PAYMENT_COUNTER,
	PAID_AND_LEAVING
}

var current_ordering_state = OrderingState.INITIAL_GREETING
var selected_food: String = ""
var is_seated = false
var settling_time: float = 0.0
var patience_timer: float = 0.0
var max_patience: float = 120.0  # 2 minutes max patience

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_area = $InteractionArea
@onready var interaction_prompt = $InteractionPrompt
@onready var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")

func _ready():
	print("DEBUG: Customer _ready() called for: " + customer_name)
	
	# Add to customers group so tables can find this customer
	add_to_group("customers")
	add_to_group("delivery_points")  # Allow food delivery to customers
	print("DEBUG: Customer " + customer_name + " added to customers group")
	
	# Verify it was added
	await get_tree().process_frame
	var customers_in_group = get_tree().get_nodes_in_group("customers")
	print("DEBUG: Total customers in group after adding: " + str(customers_in_group.size()))
	
	# Connect the interaction area signals safely
	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_interaction_area_entered):
			interaction_area.body_entered.connect(_on_interaction_area_entered)
		if not interaction_area.body_exited.is_connected(_on_interaction_area_exited):
			interaction_area.body_exited.connect(_on_interaction_area_exited)
	else:
		print("WARNING: InteractionArea not found!")
	
	# Hide UI elements initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Find dialogue UI and hide it
	setup_dialogue_ui()
	
	# Start patience timer
	start_patience_timer()

func setup_dialogue_ui():
	if not dialogue_ui:
		dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")
	if dialogue_ui:
		dialogue_ui.visible = false
	else:
		print("WARNING: DialogueUI not found! Make sure it exists in the main scene.")

func _physics_process(delta):
	handle_movement(delta)
	update_patience(delta)

func handle_movement(delta):
	if (is_walking_to_table or is_walking_to_payment) and target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		var distance = global_position.distance_to(target_position)
		
		if animated_sprite:
			animated_sprite.play("walk")
		
		# If close enough to target, stop walking
		if distance < 10.0:
			if is_walking_to_table:
				arrive_at_table()
			elif is_walking_to_payment:
				arrive_at_payment_counter()
		else:
			# Move towards the target
			velocity = direction * walking_speed
		
		move_and_slide()

func arrive_at_table():
	is_walking_to_table = false
	velocity = Vector2.ZERO
	is_seated = true
	current_ordering_state = OrderingState.SEATED_SETTLING
	print("Customer " + customer_name + " has reached their table and is settling in...")
	
	# Notify the table that customer has arrived
	if assigned_table and assigned_table.has_method("customer_seated"):
		assigned_table.customer_seated()
	
	if animated_sprite:
		animated_sprite.play("Sitting")
	
	# Start settling timer
	start_settling_timer()

func arrive_at_payment_counter():
	is_walking_to_payment = false
	velocity = Vector2.ZERO
	current_ordering_state = OrderingState.AT_PAYMENT_COUNTER
	print("Customer " + customer_name + " has arrived at the payment counter")
	
	if animated_sprite:
		animated_sprite.play("idle")  # or whatever standing animation you have
	
	# Show interaction prompt if player is nearby
	if player_in_range:
		show_interaction_prompt()

func update_patience(delta):
	# Decrease patience over time if customer is waiting
	if current_ordering_state in [OrderingState.SEATED_WAITING, OrderingState.ORDER_COMPLETE, OrderingState.AT_PAYMENT_COUNTER]:
		patience_timer += delta
		
		# Customer gets impatient after waiting too long
		if patience_timer >= max_patience:
			become_impatient()

func become_impatient():
	print("Customer " + customer_name + " is getting impatient!")
	# You could add visual effects, change dialogue, or have customer leave
	# For now, just print a warning

func start_patience_timer():
	patience_timer = 0.0

func _input(event):
	# Don't allow interaction while walking
	if is_walking_to_table or is_walking_to_payment:
		return
	
	# Check for interaction input when player is in range
	if event.is_action_pressed("interact") and player_in_range:
		if not is_talking:
			start_dialogue()
		elif is_talking:
			next_dialogue_line()

func _unhandled_input(event):
	if current_ordering_state == OrderingState.SHOWING_MENU and event.is_action_pressed("interact"):
		show_menu_options()
	elif current_ordering_state == OrderingState.WAITING_FOR_ORDER and event.is_action_pressed("interact"):
		complete_food_order()
	elif current_ordering_state == OrderingState.AT_PAYMENT_COUNTER and event.is_action_pressed("interact"):
		process_payment()

func _on_interaction_area_entered(body):
	if not is_valid_player(body):
		return
	
	player_in_range = true
	if not (is_walking_to_table or is_walking_to_payment) and can_interact():
		show_interaction_prompt()
	elif current_ordering_state == OrderingState.SEATED_SETTLING:
		show_settling_message()

func _on_interaction_area_exited(body):
	if not is_valid_player(body):
		return
	
	player_in_range = false
	hide_interaction_prompt()
	if is_talking and current_ordering_state != OrderingState.WAITING_FOR_ORDER:
		end_dialogue()

func is_valid_player(body) -> bool:
	return body.name == "Player" or body.is_in_group("player")

func can_interact() -> bool:
	match current_ordering_state:
		OrderingState.INITIAL_GREETING:
			return not has_ordered
		OrderingState.SEATED_SETTLING:
			return false
		OrderingState.SEATED_WAITING:
			return true
		OrderingState.ORDER_COMPLETE:
			return true  # Allow interaction for food delivery
		OrderingState.EATING:
			return false
		OrderingState.FINISHED:
			return true  # For triggering walk to payment
		OrderingState.WALKING_TO_PAYMENT:
			return false
		OrderingState.AT_PAYMENT_COUNTER:
			return true  # For processing payment
		OrderingState.PAID_AND_LEAVING:
			return false
		_:
			return false

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true
		# Update prompt text based on state
		update_interaction_prompt_text()

func update_interaction_prompt_text():
	if not interaction_prompt:
		return
	
	var prompt_text = interaction_prompt.get_node_or_null("Label")
	if not prompt_text:
		return
	
	match current_ordering_state:
		OrderingState.INITIAL_GREETING:
			prompt_text.text = "Press E to greet"
		OrderingState.SEATED_WAITING:
			prompt_text.text = "Press E to take order"
		OrderingState.ORDER_COMPLETE:
			prompt_text.text = "Waiting for food..."
		OrderingState.FINISHED:
			prompt_text.text = "Press E to get bill"
		OrderingState.AT_PAYMENT_COUNTER:
			prompt_text.text = "Press E to process payment"
		_:
			prompt_text.text = "Press E to interact"

func show_settling_message():
	if interaction_prompt:
		interaction_prompt.visible = false

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func start_dialogue():
	is_talking = true
	current_dialogue_index = 0
	hide_interaction_prompt()
	show_dialogue_ui()
	
	match current_ordering_state:
		OrderingState.INITIAL_GREETING:
			display_dialogue()
		OrderingState.SEATED_WAITING:
			show_menu_dialogue()
		OrderingState.FINISHED:
			show_bill_dialogue()
		OrderingState.AT_PAYMENT_COUNTER:
			show_payment_dialogue()

func next_dialogue_line():
	if current_ordering_state == OrderingState.INITIAL_GREETING:
		current_dialogue_index += 1
		if current_dialogue_index >= dialogue_lines.size():
			end_dialogue()
			complete_initial_order()
		else:
			display_dialogue()

func display_dialogue():
	if not dialogue_ui:
		print("ERROR: No DialogueUI found!")
		return
	
	update_dialogue_ui(customer_name, dialogue_lines[current_dialogue_index], "Press E to continue...")

func update_dialogue_ui(speaker: String, text: String, prompt: String):
	var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
	var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText") 
	var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
	
	if name_label:
		name_label.text = speaker
	if text_label:
		text_label.text = text
	if continue_label:
		continue_label.text = prompt

func start_settling_timer():
	# Set random settling time between 2-5 seconds
	settling_time = randf_range(2.0, 5.0)
	
	print("Customer " + customer_name + " is settling in for " + str(round(settling_time * 10) / 10) + " seconds...")
	if animated_sprite:
		animated_sprite.play("Menu")
	
	await get_tree().create_timer(settling_time).timeout
	current_ordering_state = OrderingState.SEATED_WAITING
	print("Customer " + customer_name + " is now ready to order!")
	
	if animated_sprite:
		animated_sprite.play("Sitting")
	
	# Show interaction prompt if player is nearby
	if player_in_range:
		show_interaction_prompt()

func show_menu_dialogue():
	current_ordering_state = OrderingState.SHOWING_MENU
	update_dialogue_ui(customer_name, "I'm ready to order! Let me see what I'd like...", "Press E to take their order...")
	
	# Wait for player to press E, then customer chooses automatically
	await get_tree().create_timer(0.1).timeout

func show_menu_options():
	current_ordering_state = OrderingState.WAITING_FOR_ORDER
	
	# Customer automatically chooses a random Italian food
	var random_index = randi() % available_foods.size()
	selected_food = available_foods[random_index]
	
	update_dialogue_ui(customer_name, "I think I'll have the " + selected_food + ", please!", "Press E to confirm order...")
	
	print("Customer " + customer_name + " has chosen: " + selected_food)

func complete_food_order():
	current_ordering_state = OrderingState.ORDER_COMPLETE
	
	# Add order to the OrderManager system
	var table_number = 1  # Default
	if assigned_table and assigned_table.has_method("get_table_number"):
		table_number = assigned_table.get_table_number()
	
	# Check if OrderManager exists before calling it
	if OrderManager and OrderManager.has_method("add_customer_order"):
		OrderManager.add_customer_order(customer_name, selected_food, table_number)
	else:
		print("WARNING: OrderManager not found or doesn't have add_customer_order method")
	
	update_dialogue_ui(customer_name, "Perfect! Thank you, waiter. I'll wait for my " + selected_food + "!", "Order complete!")
	
	print("Order confirmed: Customer " + customer_name + " is waiting for " + selected_food)
	
	# Hide dialogue after 3 seconds
	await get_tree().create_timer(3.0).timeout
	end_dialogue()
	
	# Reset patience timer for food waiting
	start_patience_timer()

func show_bill_dialogue():
	update_dialogue_ui(customer_name, "Thank you for the wonderful meal! I'd like to pay now.", "Press E to send them to payment counter...")
	
	# After showing dialogue, trigger walk to payment
	await get_tree().create_timer(2.0).timeout
	end_dialogue()
	walk_to_payment_counter()

func show_payment_dialogue():
	update_dialogue_ui(customer_name, "Here I am! Ready to pay for my delicious " + selected_food + ".", "Press E to process payment...")

func show_dialogue_ui():
	if dialogue_ui:
		dialogue_ui.visible = true

func hide_dialogue_ui():
	if dialogue_ui:
		dialogue_ui.visible = false

func end_dialogue():
	is_talking = false
	current_dialogue_index = 0
	hide_dialogue_ui()
	if player_in_range and can_interact():
		show_interaction_prompt()

func complete_initial_order():
	has_ordered = true
	ready_for_seating = true
	hide_interaction_prompt()

# NEW: Payment system functions
func find_payment_point():
	# Look for a node in the scene marked as payment counter
	payment_point = get_tree().current_scene.get_node_or_null("PaymentCounter")
	
	# Alternative: look for nodes in a group
	if not payment_point:
		var payment_nodes = get_tree().get_nodes_in_group("payment_counters")
		if payment_nodes.size() > 0:
			payment_point = payment_nodes[0]  # Use first available payment counter
	
	# If still not found, create a default position (you should set this manually)
	if not payment_point:
		print("WARNING: No payment counter found! Customer will walk to scene center.")
		# You can set a default position here, like:
		# target_position = Vector2(400, 300)  # Adjust coordinates as needed
		return false
	
	return true

func walk_to_payment_counter():
	current_ordering_state = OrderingState.WALKING_TO_PAYMENT
	is_seated = false  # Customer leaves their seat
	
	# Find the payment point
	if find_payment_point():
		target_position = payment_point.global_position
		is_walking_to_payment = true
		print("Customer " + customer_name + " is walking to the payment counter...")
	else:
		# Fallback: walk to a default position (you should customize this)
		target_position = Vector2(400, 300)  # Set this to your payment counter position
		is_walking_to_payment = true
		print("Customer " + customer_name + " is walking to payment area (default position)...")
	
	# Clear table assignment since customer is leaving
	if assigned_table and assigned_table.has_method("clear_table"):
		assigned_table.clear_table()
	assigned_table = null

func process_payment():
	has_paid = true
	current_ordering_state = OrderingState.PAID_AND_LEAVING
	
	update_dialogue_ui(customer_name, "Thank you for the excellent service! Here's payment for the " + selected_food + ".", "Payment received!")
	
	print("Customer " + customer_name + " has paid for their meal!")
	
	# You can add payment logic here (add money to player, etc.)
	# Example: PlayerData.add_money(get_food_price(selected_food))
	
	# Hide dialogue after 3 seconds then make customer leave
	await get_tree().create_timer(3.0).timeout
	end_dialogue()
	leave_restaurant()

func leave_restaurant():
	print("Customer " + customer_name + " is leaving the restaurant...")
	
	# Walk to exit (you can customize this)
	target_position = Vector2(-100, global_position.y)  # Walk off screen to the left
	is_walking_to_payment = true  # Reuse walking logic
	
	# Remove customer after they've walked off screen
	await get_tree().create_timer(5.0).timeout
	queue_free()

func get_food_price(food_name: String) -> int:
	# You can customize prices here
	match food_name:
		"Margherita Pizza":
			return 15
		"Fettuccine Alfredo":
			return 18
		"Lasagna Bolognese":
			return 20
		_:
			return 15  # Default price

# Food delivery system - Enhanced for manual delivery
func can_accept_delivery() -> bool:
	var can_accept = current_ordering_state == OrderingState.ORDER_COMPLETE and is_seated
	print("Customer ", customer_name, " can accept delivery: ", can_accept, " (State: ", current_ordering_state, ", Seated: ", is_seated, ")")
	return can_accept

func receive_delivery(delivered_food):
	if not can_accept_delivery():
		print("Customer " + customer_name + " cannot accept delivery right now")
		return false
	
	# Get customer's expected food
	var expected_food = get_selected_food()
	var delivered_food_type = ""
	
	# Extract food type from delivered food data
	if typeof(delivered_food) == TYPE_DICTIONARY:
		delivered_food_type = delivered_food.get("food_type", "")
	elif typeof(delivered_food) == TYPE_OBJECT and "food_type" in delivered_food:
		delivered_food_type = delivered_food.food_type
	
	print("Customer expected: ", expected_food, ", received: ", delivered_food_type)
	
	# Check if this is the right food (flexible matching)
	if not is_food_match(expected_food, delivered_food_type):
		print("Wrong food! Customer ordered ", expected_food, " but got ", delivered_food_type)
		# You could make this more forgiving for gameplay purposes
		show_wrong_food_message()
		return false
	
	print("Customer " + customer_name + " accepted delivery of " + delivered_food_type)
	current_ordering_state = OrderingState.EATING
	
	# Visual feedback for successful delivery
	show_delivery_accepted_message()
	
	# Start eating process
	start_eating()
	return true

func is_food_match(expected: String, delivered: String) -> bool:
	# Exact match
	if expected == delivered:
		return true
	
	# Flexible matching for similar food names
	var expected_lower = expected.to_lower()
	var delivered_lower = delivered.to_lower()
	
	# Check if key words match
	var expected_words = expected_lower.split(" ")
	var delivered_words = delivered_lower.split(" ")
	
	for exp_word in expected_words:
		if exp_word.length() > 3:  # Only check meaningful words
			for del_word in delivered_words:
				if exp_word in del_word or del_word in exp_word:
					return true
	
	return false

func show_wrong_food_message():
	var message = Label.new()
	message.text = "This isn't what I ordered!"
	message.position = Vector2(-40, -70)
	add_child(message)
	
	# Remove message after delay
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(message):
		message.queue_free()

func show_delivery_accepted_message():
	update_dialogue_ui(customer_name, "Thank you! This looks delicious!", "Press E to continue...")

func start_eating():
	print("Customer " + customer_name + " is now eating...")
	if animated_sprite:
		animated_sprite.play("Eating")
	
	# Eating takes 30-60 seconds
	var eating_time = randf_range(10.0, 15.0)
	await get_tree().create_timer(eating_time).timeout
	
	finish_eating()

func finish_eating():
	current_ordering_state = OrderingState.FINISHED
	print("Customer " + customer_name + " has finished eating and is ready for the bill")
	
	if animated_sprite:
		animated_sprite.play("Sitting")
	
	# Show interaction prompt if player is nearby
	if player_in_range:
		show_interaction_prompt()

# Table system functions
func is_ready_for_seating() -> bool:
	var ready = ready_for_seating and assigned_table == null
	print("DEBUG: Customer " + customer_name + " ready for seating: " + str(ready))
	return ready

func assign_to_table(table):
	assigned_table = table
	ready_for_seating = false
	print("Customer " + customer_name + " is being seated at table " + str(table.table_number))

func walk_to_table(table_position: Vector2):
	target_position = table_position
	is_walking_to_table = true
	print("Customer " + customer_name + " is walking to their table...")

# Public functions for game system
func get_selected_food() -> String:
	return selected_food

func has_completed_food_order() -> bool:
	return current_ordering_state == OrderingState.ORDER_COMPLETE

func get_customer_name() -> String:
	return customer_name

func get_current_state() -> OrderingState:
	return current_ordering_state

func has_finished_meal() -> bool:
	return current_ordering_state == OrderingState.FINISHED

func is_at_payment_counter() -> bool:
	return current_ordering_state == OrderingState.AT_PAYMENT_COUNTER

func has_completed_payment() -> bool:
	return current_ordering_state == OrderingState.PAID_AND_LEAVING
