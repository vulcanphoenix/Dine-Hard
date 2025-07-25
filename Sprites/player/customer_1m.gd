# Ultra-simple test script - attach to NPC CharacterBody2D
extends CharacterBody2D

func _ready():
	print("=== NPC SETUP CHECK ===")
	
	
	var area = $InteractionArea
	print("Found InteractionArea: ", area)
	
	
	# Connect the signal
	area.body_entered.connect(_on_body_entered)
	print("Signal connected successfully")
	print("=== SETUP COMPLETE ===")
	
	
func _on_body_entered(body):
	print("!!! BODY entered: ", body.name, " !!!")
