# OrderManager.gd - Enhanced version
extends Node

var active_orders: Dictionary = {}
var available_stations: Array = []
var delivery_locations: Dictionary = {}

signal order_created(order_data)
signal order_assigned(order_data, station_id)
signal order_completed(order_id)
signal food_ready_for_pickup(food_item, order_id)

func _ready():
	# Find all kitchen stations and delivery points
	call_deferred("register_stations_and_delivery_points")

func register_stations_and_delivery_points():
	# Register kitchen stations
	var stations = get_tree().get_nodes_in_group("kitchen_stations")
	for station in stations:
		available_stations.append(station.get_instance_id())
		print("Registered station: ", station.name)
	
	# Register delivery locations (tables, serving windows, etc.)
	var delivery_points = get_tree().get_nodes_in_group("delivery_points")
	for point in delivery_points:
		delivery_locations[point.table_id] = point
		print("Registered delivery point: ", point.table_id)

func create_order(food_type: String, customer_table: String) -> Dictionary:
	var order_data = {
		"id": generate_order_id(),
		"food_type": food_type,
		"customer_table": customer_table,
		"status": "pending",
		"created_time": Time.get_unix_time_from_system()
	}
	
	active_orders[order_data.id] = order_data
	print("Created order: ", order_data.id, " for ", food_type)
	
	order_created.emit(order_data)
	assign_order_to_station(order_data)
	
	return order_data

func assign_order_to_station(order_data: Dictionary):
	if available_stations.size() == 0:
		print("No available stations for order: ", order_data.id)
		return
	
	# Simple assignment - take first available station
	var station_id = available_stations[0]
	available_stations.erase(station_id)
	
	order_data.status = "cooking"
	order_data.assigned_station = station_id
	
	print("Assigned order ", order_data.id, " to station ", station_id)
	order_assigned.emit(order_data, station_id)

func mark_station_available(station_id: int):
	if not station_id in available_stations:
		available_stations.append(station_id)
		print("Station ", station_id, " is now available")

func get_delivery_location(order_id: String) -> Node2D:
	if order_id in active_orders:
		var table_id = active_orders[order_id].customer_table
		return delivery_locations.get(table_id, null)
	return null

func complete_order(order_id: String):
	if order_id in active_orders:
		active_orders[order_id].status = "completed"
		print("Order completed: ", order_id)
		order_completed.emit(order_id)
		
		# Remove from active orders after a delay
		await get_tree().create_timer(2.0).timeout
		active_orders.erase(order_id)

func generate_order_id() -> String:
	return "ORDER_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

# Debug function
func print_order_status():
	print("=== ORDER STATUS ===")
	for order_id in active_orders:
		var order = active_orders[order_id]
		print(order_id, ": ", order.food_type, " - Status: ", order.status)

# OrderManager.gd - Add this as an autoload singleton
# Go to Project Settings > Autoload and add this script as "OrderManage

# Structure to hold order information
class CustomerOrder:
	var customer_name: String
	var food_item: String
	var table_number: int
	var order_time: float
	var is_placed: bool = false
	var is_completed: bool = false
	
	func _init(name: String, food: String, table: int):
		customer_name = name
		food_item = food
		table_number = table
		order_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]

# Array to store all customer orders
var pending_orders: Array[CustomerOrder] = []
var placed_orders: Array[CustomerOrder] = []
var completed_orders: Array[CustomerOrder] = []

# Signals for UI updates
signal order_added(order: CustomerOrder)
signal order_placed(order: CustomerOrder)

# Add a new order when customer places it
func add_customer_order(customer_name: String, food_item: String, table_number: int):
	var new_order = CustomerOrder.new(customer_name, food_item, table_number)
	pending_orders.append(new_order)
	
	print("ORDER ADDED: " + customer_name + " ordered " + food_item + " at table " + str(table_number))
	order_added.emit(new_order)

# Get all pending orders (not yet placed in kitchen)
func get_pending_orders() -> Array[CustomerOrder]:
	return pending_orders

# Get all placed orders (sent to kitchen but not ready)
func get_placed_orders() -> Array[CustomerOrder]:
	return placed_orders

# Place an order in the kitchen
func place_order_in_kitchen(order: CustomerOrder):
	if order in pending_orders:
		pending_orders.erase(order)
		order.is_placed = true
		placed_orders.append(order)
		
		print("ORDER PLACED: " + order.customer_name + "'s " + order.food_item + " sent to kitchen")
		order_placed.emit(order)

# Place all pending orders
func place_all_orders():
	var orders_to_place = pending_orders.duplicate()
	for order in orders_to_place:
		place_order_in_kitchen(order)

# Get order by customer name (useful for delivery)
func get_order_by_customer(customer_name: String) -> CustomerOrder:
	# Check completed orders first
	for order in completed_orders:
		if order.customer_name == customer_name:
			return order
	
	# Check placed orders
	for order in placed_orders:
		if order.customer_name == customer_name:
			return order
	
	# Check pending orders
	for order in pending_orders:
		if order.customer_name == customer_name:
			return order
	
	return null

# Remove order (when delivered to customer)
func remove_order(order: CustomerOrder):
	if order in completed_orders:
		completed_orders.erase(order)
	elif order in placed_orders:
		placed_orders.erase(order)
	elif order in pending_orders:
		pending_orders.erase(order)
	
	print("ORDER DELIVERED: " + order.customer_name + "'s order has been delivered")

# Get summary of all orders for debugging
func get_order_summary() -> String:
	var summary = "=== ORDER SUMMARY ===\n"
	summary += "Pending Orders (" + str(pending_orders.size()) + "):\n"
	for order in pending_orders:
		summary += "  - " + order.customer_name + ": " + order.food_item + " (Table " + str(order.table_number) + ")\n"
	
	summary += "Placed Orders (" + str(placed_orders.size()) + "):\n"
	for order in placed_orders:
		summary += "  - " + order.customer_name + ": " + order.food_item + " (Table " + str(order.table_number) + ")\n"
	
	summary += "Completed Orders (" + str(completed_orders.size()) + "):\n"
	for order in completed_orders:
		summary += "  - " + order.customer_name + ": " + order.food_item + " (Table " + str(order.table_number) + ")\n"
	
	return summary
