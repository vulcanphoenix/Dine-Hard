extends CharacterBody2D
var speed = 400
func _physics_process(delta):
	var direction = Input.get_vector("down", "left", "right", "up")
	velocity = direction * speed
	
	move_and_slide()
