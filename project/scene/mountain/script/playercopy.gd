extends KinematicBody

#Camera
var view_sensitivity = 0.3
var view_yaw = 0
var view_pitch = 0
var camera_node_aim = Vector3()
#state
var state_fly = false
var state_moving = false
var state_on_floor = false
#action
const MAX_JUMP_TIMEOUT = 0.2
var act_jump_timeout = 0
#fly mode
var FLY_MAX_SPEED = 100
var FLY_ACCEL = 4
var FLY_DECCEL = 1
#walk mode
const JUMP_SPEED = 3*3
const WALK_MAX_SPEED = 20
const WALK_ACCEL = 2
const WALK_DECCEL = 10
const GRAVITY=-9.8*3
const MAX_SLOPE_ANGLE = 40
const STAIR_JUMP_SPEED = 5
const STAIR_JUMP_TIMEOUT = 0.2
const STAIR_RAYCAST_HEIGHT = 0.75
const STAIR_RAYCAST_DISTANCE = 0.58
var jump_timeout = 0
#move
var move_normal = Vector3()
var velocity = Vector3()


#Enable game loop(s)
func _ready():
	get_node("yaw/camera/action").add_exception(self) #prevent ray collision
	set_fixed_process(true) #_fixed_process
	set_process_input(true) #_input


#Runs when input detected
func _input(ie):
	if ie.type == InputEvent.MOUSE_MOTION:
		view_yaw = fmod(view_yaw - ie.relative_x * view_sensitivity, 360)
		view_pitch = max(min(view_pitch - ie.relative_y * view_sensitivity, 90), -90)
		get_node("yaw").set_rotation(Vector3(0, deg2rad(view_yaw), 0))
		get_node("yaw/camera").set_rotation(Vector3(deg2rad(view_pitch), 0, 0))


#Runs once per frame
func _fixed_process(delta):
	if state_fly == true:
		fly(delta)
	else:
		walk(delta)

	
func fly(delta):
	var fly_target = moveNormal() * FLY_MAX_SPEED
	var velocity = Vector3().linear_interpolate(fly_target, FLY_ACCEL*delta)
	move(velocity*delta)
	if is_colliding():
		move(get_collision_normal().slide(velocity*delta))
	
	
func walk(delta):
	move_normal = moveNormal()
	var walk_target = Vector3(move_normal.x, 0, move_normal.z) * WALK_MAX_SPEED
	
	#determine if moving or not
	var accel=WALK_DECCEL
	if state_moving:
		accel=WALK_ACCEL
	
	#move on XZ plane
	var xzVel = Vector3(velocity.x, 0, velocity.z)
	xzVel = xzVel.linear_interpolate(walk_target, accel*delta)
	velocity = Vector3(xzVel.x, velocity.y, xzVel.z)
	
	#jump
	if act_jump_timeout > 0:
			act_jump_timeout -= delta
	elif move_normal.y >0:
		print("Jump!")
		velocity.y = JUMP_SPEED
		act_jump_timeout = MAX_JUMP_TIMEOUT
		state_on_floor = false
	
	#determine if on floor
	var ray = get_node("ray")
	var ray_colliding = ray.is_colliding()
	if !state_on_floor and ray_colliding and act_jump_timeout <= 0:
		set_translation(ray.get_collision_point()) #Clamp character to floor
		state_on_floor = true
	elif state_on_floor and not ray_colliding:
		state_on_floor = false
	#What to do on the floor
	if state_on_floor:
		#Move along floor normal
		var n = ray.get_collision_normal()
		velocity = velocity-velocity.dot(n)*n
		#Apply gravity on steep slope
		if (rad2deg(acos(n.dot(Vector3(0,1,0))))) > MAX_SLOPE_ANGLE:
			velocity.y+=delta*GRAVITY
	#What to do off the floor
	else: 
		velocity.y += delta*GRAVITY
	
	move(velocity*delta)
	if(velocity.length()>0 and is_colliding()):
		move(get_collision_normal().slide(velocity*delta))

	
#Vector of direction the player wants to move.
func moveNormal():
	camera_node_aim = get_node("yaw/camera").get_global_transform().basis
	var move_normal = Vector3(0,0,0)
	if Input.is_action_pressed("GAME_JUMP"):
		move_normal.y += JUMP_SPEED
	if Input.is_action_pressed("GAME_CROUCH"):
		move_normal.y -= 1
	if Input.is_action_pressed("GAME_FRONT"):
		move_normal -= camera_node_aim[2]
	if Input.is_action_pressed("GAME_BACK"):
		move_normal += camera_node_aim[2]
	if Input.is_action_pressed("GAME_LEFT"):
		move_normal -= camera_node_aim[0]
	if Input.is_action_pressed("GAME_RIGHT"):
		move_normal += camera_node_aim[0]
	state_moving=(move_normal.length()>0)
	return(move_normal)

func _on_sceneRestart_body_enter( body ):
	set_translation(Vector3(0,3.5,-7.3))
	

