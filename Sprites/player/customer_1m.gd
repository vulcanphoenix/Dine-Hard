# Ultra-simple test script - attach to NPC CharacterBody2D
extends CharacterBody2D

func _ready():
	print("=== NPC SETUP CHECK ===")
	
	# Check if InteractionArea exists
	if not has_node("InteractionArea"):
		print("ERROR: No InteractionArea found!")
		print("You need to add an Area2D child node named 'InteractionArea'")
		return
	
	var area = $InteractionArea
	print("Found InteractionArea: ", area)
	
	# Check if it has collision shape
	if not area.has_node("CollisionShape2D"):
		print("ERROR: InteractionArea has no CollisionShape2D!")
		print("Add a CollisionShape2D as child of InteractionArea")
		return
	
	var collision = area.get_node("CollisionShape2D")
	if collision.shape == null:
		print("ERROR: CollisionShape2D has no shape!")
		print("Select the CollisionShape2D and assign a shape (RectangleShape2D, CircleShape2D, etc.)")
		return
	
	print("Shape found: ", collision.shape)
	print("Area monitoring: ", area.monitoring)
	
	# Connect the signal
	area.body_entered.connect(_on_body_entered)
	print("Signal connected successfully")
	print("=== SETUP COMPLETE ===")

func _on_body_entered(body):
	print("!!! BODY DETECTED: ", body.name, " !!!")

# Simple test - add this to your PLAYER script:
# extends CharacterBody2D
# 
# func _ready():
#     add_to_group("player")
#     print("Player ready - groups: ", get_groups())
# 
# # Your movement code here
