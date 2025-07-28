extends CharacterBody2D

# Restaurant Customer NPC with In-Game Dialogue UI

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

@onready var interaction_area = $InteractionArea
@onready var interaction_prompt = $InteractionPrompt
@onready var dialogue_ui = $DialogueUI

func _ready():
	# Connect the interaction area signals
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Hide UI elements initially
	if interaction_prompt:
		interaction_prompt.visible = false
	if dialogue_ui:
		dialogue_ui.visible = false

func _input(event):
	# Check for interaction input when player is in range
	if event.is_action_pressed("interact") and player_in_range and not is_talking:
		start_dialogue()
	elif event.is_action_pressed("interact") and is_talking:
		next_dialogue_line()

func _on_interaction_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_in_range = true
		if not has_ordered:
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
	if dialogue_ui:
		var name_label = dialogue_ui.get_node("DialogueBox/NameLabel")
		var text_label = dialogue_ui.get_node("DialogueBox/DialogueText")
		var continue_label = dialogue_ui.get_node("DialogueBox/ContinuePrompt")
		
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
	hide_interaction_prompt()
	
	# Show completion message briefly
	if dialogue_ui:
		var name_label = dialogue_ui.get_node("DialogueBox/NameLabel")
		var text_label = dialogue_ui.get_node("DialogueBox/DialogueText")
		var continue_label = dialogue_ui.get_node("DialogueBox/ContinuePrompt")
		
		if name_label:
			name_label.text = customer_name
		if text_label:
			text_label.text = "*Order completed* Thank you for the excellent service!"
		if continue_label:
			continue_label.text = ""
		
		# Hide dialogue after 2 seconds
		await get_tree().create_timer(2.0).timeout
		hide_dialogue_ui()
