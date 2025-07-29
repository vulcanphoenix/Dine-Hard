extends Node2D

# In your main scene script
func _ready():
	# After instantiating the customer
	var customer = get_node("RestaurantCustomer")  # Adjust path as needed
	customer.add_to_group("customers")
	print("Manually added customer to group")
