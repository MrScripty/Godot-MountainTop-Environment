extends Node

#Get updated on input event
func _ready():
	set_process_input(true)

#end the game
func _input(ie):
	if Input.is_action_pressed("APP_QUIT"):
		get_tree().quit()

#Run once when the game ends
func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
