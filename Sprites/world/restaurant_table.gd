extends StaticBody2D

# Restaurant Table Script - attach this to a StaticBody2D table

@export var table_number: int = 1
@export var is_occupied: bool = false
@export var assigned_customer: CharacterBody2D = null

var player_in_range = false
var customer_walking_speed = 50.0

@onready var interaction_area = $InteractionArea
@onready var interaction_prompt = $InteractionPrompt
@onready var customer_seat_position = $CustomerSeatPosition

func _ready():
	# Connect the interaction area signals
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

func _input(event):
	if event.is_action_pressed("interact") and player_in_range and not is_occupied:
		seat_waiting_customer()

func _on_interaction_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = true
		if not is_occupied:
			show_interaction_prompt()

func _on_interaction_area_exited(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = false
		hide_interaction_prompt()

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.text = "Press E to Interact"
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func seat_waiting_customer():
	# Find customers by group first
	var customers = get_tree().get_nodes_in_group("customers")
	print("DEBUG: Found " + str(customers.size()) + " customers in group")
	
	# If group is empty, try scene traversal as backup
	if customers.size() == 0:
		print("DEBUG: Searching for customers by traversing scene tree...")
		customers = find_all_customers(get_tree().current_scene)
		print("DEBUG: Found " + str(customers.size()) + " customers by scene traversal")
	
	var customer_to_seat = null
	
	for customer in customers:
		# Safely check if customer has the required properties and methods
		if not customer.has_method("is_ready_for_seating"):
			print("DEBUG: Customer doesn't have is_ready_for_seating method")
			continue
			
		var customer_name = "Unknown"
		if "customer_name" in customer:
			customer_name = customer.customer_name
		
		print("DEBUG: Checking customer " + customer_name)
		
		# Check the customer's internal state
		if "ready_for_seating" in customer:
			print("DEBUG: ready_for_seating = " + str(customer.ready_for_seating))
		if "has_ordered" in customer:
			print("DEBUG: has_ordered = " + str(customer.has_ordered))
		if "assigned_table" in customer:
			print("DEBUG: assigned_table = " + str(customer.assigned_table))
		
		print("DEBUG: Customer ready for seating: " + str(customer.is_ready_for_seating()))
		
		if customer.is_ready_for_seating():
			customer_to_seat = customer
			break
	
	if customer_to_seat:
		assign_customer(customer_to_seat)
		move_customer_to_table(customer_to_seat)
	else:
		print("No customers waiting to be seated!")

func find_all_customers(node):
	var customers = []
	
	# Check if this node is a customer (has customer_name property)
	if node.has_method("get") and "customer_name" in node and node.customer_name != "":
		customers.append(node)
	
	# Check all children recursively
	for child in node.get_children():
		customers.append_array(find_all_customers(child))
	
	return customers

func assign_customer(customer: CharacterBody2D):
	assigned_customer = customer
	is_occupied = true
	hide_interaction_prompt()
	
	# Tell the customer they've been assigned to this table
	if customer.has_method("assign_to_table"):
		customer.assign_to_table(self)
	
	print("Customer " + customer.customer_name + " assigned to Table " + str(table_number))

func move_customer_to_table(customer: CharacterBody2D):
	if not customer_seat_position:
		print("Warning: No CustomerSeatPosition marker found!")
		return
	
	# Tell customer to walk to the table
	var target_position = customer_seat_position.global_position
	
	if customer.has_method("walk_to_table"):
		customer.walk_to_table(target_position)
	else:
		print("Error: Customer doesn't have walk_to_table method!")

func customer_seated():
	print("Customer " + assigned_customer.customer_name + " is now seated at Table " + str(table_number))
	# You could add more logic here like:
	# - Start a timer for the customer's meal
	# - Change customer sprite to sitting
	# - Enable food ordering

func free_table():
	# Call this when customer leaves
	assigned_customer = null
	is_occupied = false
	print("Table " + str(table_number) + " is now available")
	
	# Show interaction prompt again if player is nearby
	if player_in_range:
		show_interaction_prompt()
