extends KinematicBody

#global
const Button_class=preload("res://scene/dev_world_flat/script/button.gd")

#camera
var view_sensitivity = 0.3
var yaw = 0
var pitch = 0

#state
var fly_mode = false

#fly movment
const FLY_SPEED = 100
const FLY_ACCEL = 4
var velocity = Vector3()

#walk movment
const WALK_MAX_SPEED = 15
const ACCEL = 2
const DEACCEL = 4
const GRAVITY=-9.8*3
const JUMP_SPEED = 3*3
const MAX_SLOPE_ANGLE = 40
const MAX_JUMP_TIMEOUT = 0.2
const STAIR_RAYCAST_HEIGHT = 0.75
const STAIR_RAYCAST_DISTANCE = 0.58
const STAIR_JUMP_SPEED = 5
const STAIR_JUMP_TIMEOUT = 0.2
var is_moving=false
var on_floor = false
var jump_timeout = 0


func _input(ie):
	#Mouse look
	if ie.type == InputEvent.MOUSE_MOTION:
		yaw = fmod(yaw - ie.relative_x * view_sensitivity, 360)
		pitch = max(min(pitch - ie.relative_y * view_sensitivity, 90), -90)
		get_node("yaw").set_rotation(Vector3(0, deg2rad(yaw), 0))
		get_node("yaw/camera").set_rotation(Vector3(deg2rad(pitch), 0, 0))
		
	if ie.type == InputEvent.KEY:
		if Input.is_action_pressed("GAME_USE"):
			var ray=get_node("yaw/camera/action")
			if ray.is_colliding():
				var obj=ray.get_collider()
				if obj extends Button_class:
					obj.on_pressed()
	
func _fixed_process(delta):
	if fly_mode:
		_fly(delta)
	else:
		_walk(delta)

func _ready():
	get_node("yaw/camera/action").add_exception(self)
	set_fixed_process(true)
	set_process_input(true)
	
#Run once when the game starts
func _enter_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

#Run once when the game ends
func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func _fly(delta):
	# read the rotation of the camera
	var aim = get_node("yaw/camera").get_global_transform().basis
	# calculate the direction where the player want to move
	var direction = Vector3()
	if Input.is_action_pressed("GAME_FRONT"):
		direction -= aim[2]
	if Input.is_action_pressed("GAME_BACK"):
		direction += aim[2]
	if Input.is_action_pressed("GAME_LEFT"):
		direction -= aim[0]
	if Input.is_action_pressed("GAME_RIGHT"):
		direction += aim[0]
		
	direction = direction.normalized()
	
	# calculate the target where the player want to move
	var target=direction*FLY_SPEED
	
	# calculate the velocity to move the player toward the target
	velocity=Vector3().linear_interpolate(target,FLY_ACCEL*delta)
	
	# move the node
	var motion=velocity*delta
	motion=move(motion)
	
	# slide until it doesn\u2019t need to slide anymore,
	#or after n times
	var original_vel=velocity
	var attempts=4 # number of attempts to slide the node
	
	while(attempts and is_colliding()):
		var n=get_collision_normal()
		motion=n.slide(motion)
		velocity=n.slide(velocity)
		# check that the resulting velocity is not opposite to
		# the original velocity, which would mean moving backward.
		if(original_vel.dot(velocity)>0):
			motion=move(motion)
			if (motion.length()<0.001):
				break
		attempts-=1
		
func _walk(delta):
	var ray = get_node("ray")
	var step_ray=get_node("stepRay")
	
	# process timers
	if jump_timeout > 0:
		jump_timeout-=delta
	
	# read the rotation of the camera
	var aim = get_node("yaw/camera").get_global_transform().basis
	
	# calculate the direction where the player want to move
	var direction = Vector3()
	if Input.is_action_pressed("GAME_FRONT"):
		direction -= aim[2]
	if Input.is_action_pressed("GAME_BACK"):
		direction += aim[2]
	if Input.is_action_pressed("GAME_LEFT"):
		direction -= aim[0]
	if Input.is_action_pressed("GAME_RIGHT"):
		direction += aim[0]
	if on_floor:
		if Input.is_action_pressed("GAME_JUMP"):
			velocity.y=JUMP_SPEED
			jump_timeout=MAX_JUMP_TIMEOUT
			on_floor=false
		
	#reset the flag for actora\u2019s movement state
	is_moving=(direction.length()>0)
		
	direction.y=0
	direction = direction.normalized()
	# clamp to ground if not jumping. Check only the first time a
	# collision is detected (landing from a fall)
	var is_ray_colliding=ray.is_colliding()
	
	if !on_floor and jump_timeout<=0 and is_ray_colliding:
		set_translation(ray.get_collision_point())
		on_floor=true
	elif on_floor and not is_ray_colliding:
		# check that flag on_floor still reflects the state of the ray.
		on_floor=false
	
	if on_floor:
		# if on floor move along the floor. To do so, we calculate the
		# velocity perpendicular to the normal of the floor.
		var n=ray.get_collision_normal()
		velocity=velocity-velocity.dot(n)*n
		# apply gravity if on a slope too steep
		if (rad2deg(acos(n.dot(Vector3(0,1,0))))> MAX_SLOPE_ANGLE):
			velocity.y+=delta*GRAVITY
	else:
		# apply gravity if falling
		velocity.y+=delta*GRAVITY

	if on_floor:
		# if on floor move along the floor. To do so, we calculate the
		# velocity perpendicular to the normal of the floor.
		var n=ray.get_collision_normal()
		velocity=velocity-velocity.dot(n)*n
		# if the character is in front of a stair, and if the step is
		# flat enough, jump to the step.
		if is_moving and step_ray.is_colliding():
			var step_normal=step_ray.get_collision_normal()
			if (rad2deg(acos(step_normal.dot(Vector3(0,1,0))))< MAX_SLOPE_ANGLE):
				velocity.y=STAIR_JUMP_SPEED
				jump_timeout=STAIR_JUMP_TIMEOUT
	
		# apply gravity if on a slope too steep
		if (rad2deg(acos(n.dot(Vector3(0,1,0))))> MAX_SLOPE_ANGLE):
			velocity.y+=delta*GRAVITY
	else:
		# apply gravity if falling
		velocity.y+=delta*GRAVITY
	
	var target=direction*WALK_MAX_SPEED
	# if the character is moving, he must accelerate.
	# Otherwise he deccelerates.
	var accel=DEACCEL
	if is_moving:
		accel=ACCEL
	
	# calculate velocity\u2019s change
	var hvel=velocity
	hvel.y=0
	# calculate the velocity to move toward the target,
	# but only on the horizontal plane XZ
	hvel=hvel.linear_interpolate(target,accel*delta)
	velocity.x=hvel.x
	velocity.z=hvel.z
	
	# move the node
	var motion=velocity*delta
	motion=move(motion)
	
	# slide until it doesn\u2019t need to slide anymore,
	#or after n times
	var original_vel=velocity
	if(motion.length()>0 and is_colliding()):
		var n=get_collision_normal()
		motion=n.slide(motion)
		velocity=n.slide(velocity)
		# check that the resulting velocity is not opposite to the
		# original velocity, which would mean moving backward.
		if(original_vel.dot(velocity)>0):
			motion=move(motion)
			
	# update the position of the raycast for stairs to where the
	# character is trying to go, so it will cast the ray at the next
	# loop.
	if is_moving:
		var sensor_position=Vector3(direction.z,0,-direction.x)*STAIR_RAYCAST_DISTANCE
		sensor_position.y=STAIR_RAYCAST_HEIGHT
		step_ray.set_translation(sensor_position)

func _on_Area_body_enter( body ):
	fly_mode=true

func _on_Area_body_exit( body ):
	fly_mode=false
