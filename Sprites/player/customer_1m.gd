extends CharacterBody2D

# Restaurant Customer NPC with In-Game Dialogue UI and Walking Movement
# This script goes on the root node of the NPC scene file

@export var customer_name: String = "Mrs. Anderson"
@export var dialogue_lines: Array[String] = [
	"Excuse me, waiter! Could I get some service?",
	"I'd like to see the menu, please.",
	"What would you recommend for tonight?",
	"Perfect! I'll have that then. Thank you!"
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
		
		# If close enough to target, stop walking
		if distance < 10.0:
			is_walking_to_table = false
			velocity = Vector2.ZERO
			print("Customer " + customer_name + " has reached their table!")
			# Notify the table that customer has arrived
			if assigned_table and assigned_table.has_method("customer_seated"):
				assigned_table.customer_seated()
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

func _on_interaction_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = true
		if not has_ordered and not is_walking_to_table:
			show_interaction_prompt()

func _on_interaction_area_exited(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = false
		hide_interaction_prompt()
		end_dialogue()

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func start_dialogue():
	is_talking = true
	current_dialogue_index = 0
	hide_interaction_prompt()
	show_dialogue_ui()
	display_dialogue()

func next_dialogue_line():
	current_dialogue_index += 1
	if current_dialogue_index >= dialogue_lines.size():
		end_dialogue()
		complete_order()
	else:
		display_dialogue()

func display_dialogue():
	if not dialogue_ui:
		print("ERROR: No DialogueUI found!")
		return
		
	var name_label = dialogue_ui.get_node_or_null("DialogueBox/NameLabel")
	var text_label = dialogue_ui.get_node_or_null("DialogueBox/DialogueText") 
	var continue_label = dialogue_ui.get_node_or_null("DialogueBox/ContinuePrompt")
	
	if not name_label:
		print("ERROR: NameLabel not found at DialogueBox/NameLabel")
	if not text_label:
		print("ERROR: DialogueText not found at DialogueBox/DialogueText")
	if not continue_label:
		print("ERROR: ContinuePrompt not found at DialogueBox/ContinuePrompt")
	
	if name_label:
		name_label.text = customer_name
	if text_label:
		text_label.text = dialogue_lines[current_dialogue_index]
	if continue_label:
		continue_label.text = "Press E to continue..."

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
	if player_in_range and not has_ordered:
		show_interaction_prompt()

func complete_order():
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

# New functions for table system
func is_ready_for_seating() -> bool:
	var ready = ready_for_seating and assigned_table == null
	print("DEBUG: Customer " + customer_name + " ready for seating: " + str(ready))
	print("DEBUG: ready_for_seating = " + str(ready_for_seating) + ", assigned_table = " + str(assigned_table))
	return ready

func assign_to_table(table):
	assigned_table = table
	ready_for_seating = false
	print("Customer " + customer_name + " is being seated at table " + str(table.table_number))

# New function to start walking to table
func walk_to_table(table_position: Vector2):
	target_position = table_position
	is_walking_to_table = true
	print("Customer " + customer_name + " is walking to their table...")
