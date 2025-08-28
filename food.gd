extends Area2D

# Food properties
var order_id: String
var food_type: String
var customer_name: String = ""
var table_number: int = 0
var ready_for_collection: bool = false
var cook_time: float = 0.0  # How long it took to cook
var temperature: String = "hot"  # hot, warm, cold

# Visual and feedback
var ready_tween: Tween
var collection_feedback_shown: bool = false

# Signals
signal collected(collector)
signal food_spoiled(food_item)

# Node references
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var ready_indicator = null  # We'll create this dynamically

func _ready():
	# Add to groups
	add_to_group("ready_food")
	add_to_group("food_items")
	
	# Connect signals safely
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Set collision layers/masks for waiter detection
	collision_layer = 4  # Food layer (bit 2)
	collision_mask = 2   # Waiter layer (bit 1)
	
	
	# Show ready indicator if already ready
	if ready_for_collection:
		show_ready_indicator()
	
	print("Food item created: ", food_type, " (Order ID: ", order_id, ")")


func _on_body_entered(body):
	if not is_instance_valid(body):
		return
	
	# Show collection prompt when waiter is nearby
	if body.is_in_group("waiters") and ready_for_collection:
		show_collection_feedback()
		
		# Auto-collect if enabled (you can make this optional)
		if should_auto_collect():
			collect_food(body)

func _on_body_exited(body):
	if not is_instance_valid(body):
		return
	
	# Hide collection prompt when waiter leaves
	if body.is_in_group("waiters"):
		hide_collection_feedback()

func should_auto_collect() -> bool:
	# You can add logic here to determine if food should auto-collect
	# For now, always auto-collect when ready
	return ready_for_collection

func show_collection_feedback():
	if collection_feedback_shown:
		return
	
	collection_feedback_shown = true
	
	# Create a "Press E to collect" indicator or similar
	var feedback_label = Label.new()
	feedback_label.name = "CollectionFeedback"
	feedback_label.text = "Ready to collect!"
	feedback_label.position = Vector2(-30, -40)
	feedback_label.add_theme_font_size_override("font_size", 12)
	add_child(feedback_label)
	
	# Animate the feedback
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
	tween.tween_property(feedback_label, "modulate:a", 1.0, 0.5)
	tween.set_loops()

func hide_collection_feedback():
	collection_feedback_shown = false
	var feedback = get_node_or_null("CollectionFeedback")
	if feedback:
		feedback.queue_free()

func collect_food(collector):
	if not ready_for_collection or not is_instance_valid(collector):
		print("Cannot collect food: ready=", ready_for_collection, ", collector valid=", is_instance_valid(collector))
		return false
	
	print("Food collected: ", food_type, " (Order: ", order_id, ") by ", collector.name)
	
	# Check if collector can carry more food
	if collector.has_method("receive_food"):
		var success = collector.receive_food(self)
		if not success:
			print("Collector cannot carry more food!")
			show_carry_full_message()
			return false
	else:
		print("Warning: Collector doesn't have receive_food method!")
		return false
	
	# Play collection sound effect (if you have audio)
	play_collection_sound()
	
	# Emit collection signal
	collected.emit(collector)
	
	
	# Clean up and remove
	cleanup_and_remove()
	return true

func show_carry_full_message():
	var message = Label.new()
	message.text = "Hands Full!"
	message.position = Vector2(-20, -50)
	add_child(message)
	
	# Remove message after delay
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(message):
		message.queue_free()

func play_collection_sound():
	# Add sound effect here when you have audio files
	# Example:
	# if has_node("AudioStreamPlayer2D"):
	#     $AudioStreamPlayer2D.play()
	pass

func cleanup_and_remove():
	# Stop any running tweens
	if ready_tween:
		ready_tween.kill()
	
	# Clean up feedback elements
	hide_collection_feedback()
	
	# Remove ready indicator
	if ready_indicator:
		ready_indicator.queue_free()
	
	# Remove from scene
	queue_free()

func show_ready_indicator():
	if ready_indicator:
		return  # Already showing
	
	# Create visual ready indicator
	ready_indicator = Sprite2D.new()
	ready_indicator.name = "ReadyIndicator"
	
	# Create a simple colored circle texture
	var texture = ImageTexture.new()
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	texture.set_image(image)
	ready_indicator.texture = texture
	ready_indicator.position = Vector2(0, -25)
	add_child(ready_indicator)
	
	# Animate the ready indicator
	ready_tween = create_tween()
	ready_tween.set_loops()
	ready_tween.tween_property(ready_indicator, "scale", Vector2(1.2, 1.2), 0.5)
	ready_tween.tween_property(ready_indicator, "scale", Vector2(1.0, 1.0), 0.5)

# Methods for the cooking station to set order information
func set_order_info(table_num: int, food_name: String, customer: String):
	order_id = str(table_num)
	food_type = food_name
	customer_name = customer
	table_number = table_num
	ready_for_collection = true
	
	show_ready_indicator()
	
	print("Food ready: ", food_name, " for ", customer, " at table ", table_num, " (Order ID: ", order_id, ")")

# Individual setter methods for flexibility
func set_order_id(id: String):
	order_id = id

func set_order_id_int(id: int):
	order_id = str(id)

func set_customer_name(name: String):
	customer_name = name

func set_table_number(num: int):
	table_number = num

func set_ready(is_ready: bool):
	ready_for_collection = is_ready
	if ready_for_collection:
		show_ready_indicator()
	else:
		if ready_indicator:
			ready_indicator.queue_free()
			ready_indicator = null
		if ready_tween:
			ready_tween.kill()

func make_collectable():
	set_ready(true)


# Debug method
func get_food_info() -> Dictionary:
	return {
		"order_id": order_id,
		"food_type": food_type,
		"customer_name": customer_name,
		"table_number": table_number,
		"ready": ready_for_collection,
	}
