# OrderManager.gd - Add this as an autoload singleton
# Go to Project Settings > Autoload and add this script as "OrderManager"

extends Node

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
signal order_completed(order: CustomerOrder)

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

# Complete an order (when kitchen finishes it)
func complete_order(order: CustomerOrder):
	if order in placed_orders:
		placed_orders.erase(order)
		order.is_completed = true
		completed_orders.append(order)
		
		print("ORDER COMPLETED: " + order.customer_name + "'s " + order.food_item + " is ready!")
		order_completed.emit(order)

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
