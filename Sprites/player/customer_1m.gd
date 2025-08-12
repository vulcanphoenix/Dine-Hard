extends CharacterBody2D

# Restaurant Customer NPC with Automatic Italian Food Selection
# This script goes on the root node of the NPC scene file

@export var customer_name: String = "Mr. Anderson"
@export var dialogue_lines: Array[String] = [
	"Excuse me, waiter! Could I get some service?",
	"Table for One please",
]

# Food ordering system - Italian themed options
@export var available_foods: Array[String] = [
	"Spaghetti Carbonara",
	"Margherita Pizza", 
	"Chicken Parmigiana",
	"Fettuccine Alfredo",
	"Lasagna Bolognese",
	"Risotto ai Funghi"
]

var player_in_range = false
var current_dialogue_index = 0
var is_talking = false
var has_ordered = false
var ready_for_seating = false
var assigned_table = null
var is_walking_to_table = false
var target_position = Vector2.ZERO
var walking_speed = 160.0

# Ordering system states
enum OrderingState {
	INITIAL_GREETING,
	SEATED_SETTLING,
	SEATED_WAITING,
	SHOWING_MENU,
	WAITING_FOR_ORDER,
	ORDER_COMPLETE
}

var current_ordering_state = OrderingState.INITIAL_GREETING
var selected_food: String = ""
var is_seated = false
var settling_time: float = 0.0  # Will be set randomly when customer sits

@onready var _animated_sprite = $AnimatedSprite2D
@onready var interaction_area = $InteractionArea
@onready var interaction_prompt = $InteractionPrompt
@onready var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")

func _ready():
	print("DEBUG: Customer _ready() called for: " + customer_name)
	
	# Add to customers group so tables can find this customer
	add_to_group("customers")
	print("DEBUG: Customer " + customer_name + " added to customers group")
	
	# Verify it was added
	await get_tree().process_frame  # Wait one frame
	var customers_in_group = get_tree().get_nodes_in_group("customers")
	print("DEBUG: Total customers in group after adding: " + str(customers_in_group.size()))
	for customer in customers_in_group:
		if customer.has_method("get") and "customer_name" in customer:
			print("DEBUG: Customer in group: " + str(customer.customer_name))
	
	# Connect the interaction area signals
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Hide UI elements initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Find dialogue UI and hide it
	if not dialogue_ui:
		dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")
	if dialogue_ui:
		dialogue_ui.visible = false
	else:
		print("WARNING: DialogueUI not found! Make sure it exists in the main scene.")

func _physics_process(delta):
	# Handle movement to table
	if is_walking_to_table and target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		var distance = global_position.distance_to(target_position)
		_animated_sprite.play("walk")
		
		# If close enough to target, stop walking
		if distance < 10.0:
			is_walking_to_table = false
			velocity = Vector2.ZERO
			is_seated = true
			current_ordering_state = OrderingState.SEATED_SETTLING
			print("Customer " + customer_name + " has reached their table and is settling in...")
			# Notify the table that customer has arrived
			if assigned_table and assigned_table.has_method("customer_seated"):
				assigned_table.customer_seated()
				_animated_sprite.play("Sitting")
			
			# Start settling timer
			start_settling_timer()
		else:
			# Move towards the target
			velocity = direction * walking_speed
		
		move_and_slide()

func _input(event):
	# Don't allow interaction while walking to table
	if is_walking_to_table:
		return
		
	# Check for interaction input when player is in range
	if event.is_action_pressed("interact") and player_in_range and not is_talking:
		start_dialogue()
	elif event.is_action_pressed("interact") and is_talking:
		next_dialogue_line()

func _unhandled_input(event):
	if current_ordering_state == OrderingState.SHOWING_MENU and event.is_action_pressed("interact"):
		show_menu_options()
	elif current_ordering_state == OrderingState.WAITING_FOR_ORDER and event.is_action_pressed("interact"):
		# Player confirms the customer's choice
		complete_food_order()

func _on_interaction_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = true
		if not is_walking_to_table and can_interact():
			show_interaction_prompt()
		elif current_ordering_state == OrderingState.SEATED_SETTLING:
			show_settling_message()

func _on_interaction_area_exited(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = false
		hide_interaction_prompt()
		if is_talking and current_ordering_state != OrderingState.WAITING_FOR_ORDER:
			end_dialogue()

func can_interact() -> bool:
	match current_ordering_state:
		OrderingState.INITIAL_GREETING:
			return not has_ordered
		OrderingState.SEATED_SETTLING:
			return false  # Customer is not ready to interact yet
		OrderingState.SEATED_WAITING:
			return true
		OrderingState.ORDER_COMPLETE:
			return false
		_:
			return false

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true

func show_settling_message():
	# Show a temporary message that customer is still settling in
	if interaction_prompt:
		# You could change the interaction prompt text or create a different visual indicator
		# For now, we'll just not show the prompt during settling
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
		
	var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
	var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText") 
	var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
	
	if name_label:
		name_label.text = customer_name
	if text_label:
		text_label.text = dialogue_lines[current_dialogue_index]
	if continue_label:
		continue_label.text = "Press E to continue..."

func start_settling_timer():
	# Set random settling time between 3-8 seconds
	settling_time = randf_range(3.0, 8.0)
	
	# Customer needs time to settle in before being ready to order
	print("Customer " + customer_name + " is settling in for " + str(round(settling_time * 10) / 10) + " seconds...")
	_animated_sprite.play("Menu")
	await get_tree().create_timer(settling_time).timeout
	current_ordering_state = OrderingState.SEATED_WAITING
	print("Customer " + customer_name + " is now ready to order!")
	_animated_sprite.play("Sitting")
	
	# Show interaction prompt if player is nearby
	if player_in_range:
		show_interaction_prompt()

func show_menu_dialogue():
	current_ordering_state = OrderingState.SHOWING_MENU
	
	var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
	var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText") 
	var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
	
	if name_label:
		name_label.text = customer_name
	if text_label:
		text_label.text = "I'm ready to order! Let me see what I'd like..."
	if continue_label:
		continue_label.text = "Press E to take their order..."
	
	# Wait for player to press E, then customer chooses automatically
	await get_tree().create_timer(0.1).timeout  # Small delay to prevent immediate triggering

func show_menu_options():
	current_ordering_state = OrderingState.WAITING_FOR_ORDER
	
	# Customer automatically chooses a random Italian food
	var random_index = randi() % available_foods.size()
	selected_food = available_foods[random_index]
	
	var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
	var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText") 
	var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
	
	if name_label:
		name_label.text = customer_name
	if text_label:
		text_label.text = "I think I'll have the " + selected_food + ", please!"
	if continue_label:
		continue_label.text = "Press E to confirm order..."
	
	print("Customer " + customer_name + " has chosen: " + selected_food)

func complete_food_order():
	current_ordering_state = OrderingState.ORDER_COMPLETE
	
	var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
	var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText") 
	var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
	
	if name_label:
		name_label.text = customer_name
	if text_label:
		text_label.text = "Perfect! Thank you, waiter. I'll wait for my " + selected_food + "!"
	if continue_label:
		continue_label.text = "Order complete!"
	
	print("Order confirmed: Customer " + customer_name + " is waiting for " + selected_food)
	
	# Hide dialogue after 3 seconds
	await get_tree().create_timer(3.0).timeout
	end_dialogue()

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
	ready_for_seating = true  # Customer is now ready to be seated
	hide_interaction_prompt()
	
	# Show completion message briefly
	if dialogue_ui:
		var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
		var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText")
		var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
		
		if name_label:
			name_label.text = customer_name
		if text_label:
			text_label.text = "*Order taken* Please show me to my table!"
		if continue_label:
			continue_label.text = ""
		
		# Hide dialogue after 2 seconds
		await get_tree().create_timer(2.0).timeout
		hide_dialogue_ui()

# Table system functions
func is_ready_for_seating() -> bool:
	var ready = ready_for_seating and assigned_table == null
	print("DEBUG: Customer " + customer_name + " ready for seating: " + str(ready))
	print("DEBUG: ready_for_seating = " + str(ready_for_seating) + ", assigned_table = " + str(assigned_table))
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
