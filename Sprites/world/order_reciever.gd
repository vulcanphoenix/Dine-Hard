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
