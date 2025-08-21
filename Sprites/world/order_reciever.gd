# KitchenStation.gd
# Attach this script to your kitchen station/order terminal node

extends StaticBody2D

var player_in_range = false
var is_showing_orders = false

@onready var interaction_area = $InteractionArea  # Area2D for detecting player
@onready var interaction_prompt = $InteractionPrompt  # Label showing "Press E to place orders"
@onready var orders_ui = get_tree().current_scene.get_node_or_null("OrdersUI")  # UI for showing orders

func _ready():
	# Connect the interaction area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Hide UI elements initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Find or create orders UI
	if not orders_ui:
		orders_ui = get_tree().current_scene.get_node_or_null("OrdersUI")
	
	if orders_ui:
		orders_ui.visible = false
	else:
		print("WARNING: OrdersUI not found! Make sure it exists in the main scene.")

func _input(event):
	# Check for interaction input when player is in range
	if event.is_action_pressed("interact") and player_in_range and not is_showing_orders:
		show_orders()
	elif event.is_action_pressed("interact") and is_showing_orders:
		# If viewing orders, pressing E places all orders
		place_all_orders()
	elif event.is_action_pressed("ui_cancel") and is_showing_orders:
		# ESC or similar to close orders view
		hide_orders()

func _on_interaction_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = true
		show_interaction_prompt()

func _on_interaction_area_exited(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = false
		hide_interaction_prompt()
		if is_showing_orders:
			hide_orders()

func show_interaction_prompt():
	if interaction_prompt:
		var pending_count = OrderManager.get_pending_orders().size()
		if pending_count > 0:
			interaction_prompt.text = "Press E to place " + str(pending_count) + " orders"
			interaction_prompt.visible = true
		else:
			interaction_prompt.text = "No orders to place"
			interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func show_orders():
	is_showing_orders = true
	hide_interaction_prompt()
	
	if orders_ui:
		orders_ui.visible = true
		update_orders_display()
	else:
		# Fallback: print orders to console if no UI exists
		print(OrderManager.get_order_summary())

func hide_orders():
	is_showing_orders = false
	if orders_ui:
		orders_ui.visible = false
	if player_in_range:
		show_interaction_prompt()

func update_orders_display():
	if not orders_ui:
		return
	
	# Update the orders list in the UI
	var orders_list = orders_ui.get_node_or_null("OrdersList")  # VBoxContainer or similar
	var place_button = orders_ui.get_node_or_null("PlaceOrdersButton")  # Button to place all orders
	var close_button = orders_ui.get_node_or_null("CloseButton")  # Button to close UI
	
	# Clear existing order items
	if orders_list:
		for child in orders_list.get_children():
			child.queue_free()
		
		# Add each pending order to the list
		var pending_orders = OrderManager.get_pending_orders()
		
		if pending_orders.size() == 0:
			var no_orders_label = Label.new()
			no_orders_label.text = "No pending orders"
			orders_list.add_child(no_orders_label)
		else:
			for order in pending_orders:
				var order_label = Label.new()
				order_label.text = "Table " + str(order.table_number) + ": " + order.customer_name + " - " + order.food_item
				orders_list.add_child(order_label)
	
	# Connect buttons if they exist
	if place_button and not place_button.pressed.is_connected(place_all_orders):
		place_button.pressed.connect(place_all_orders)
	
	if close_button and not close_button.pressed.is_connected(hide_orders):
		close_button.pressed.connect(hide_orders)

func place_all_orders():
	var pending_orders = OrderManager.get_pending_orders()
	var order_count = pending_orders.size()
	
	if order_count > 0:
		OrderManager.place_all_orders()
		print("Placed " + str(order_count) + " orders in the kitchen!")
		
		# Update display or hide UI
		if is_showing_orders:
			update_orders_display()
		else:
			hide_orders()
	else:
		print("No orders to place!")

# Optional: Add individual order placement
func place_single_order(order: OrderManager.CustomerOrder):
	OrderManager.place_order_in_kitchen(order)
	if is_showing_orders:
		update_orders_display()
