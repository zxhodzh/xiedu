class_name Player
extends CharacterBody2D

enum Direction {
	LEFT = -1,
	RIGHT = +1,
}

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	SLID,
	WALLJUMP,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	DOWN,
	SLIDING_START,
	SLIDING_LOOP,
	SLIDING_END,
	ROLL,
}


@onready var 动画node_2d: Node2D = $"动画Node2D"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var 郊狼Timer: Timer = $"郊狼Timer"
@onready var 可跳跃Timer: Timer = $"可跳跃Timer"
@onready var 手_ray_cast_2d: RayCast2D = $"动画Node2D/手RayCast2D"
@onready var 脚_ray_cast_2d: RayCast2D = $"动画Node2D/脚RayCast2D"
@onready var state_machine: StateMachine = $StateMachine
@export var can_combo := false
@onready var slide_request_timer: Timer = $SlideRequestTimer
@onready var stats: Node = Game.player_stats



const SLIDING_DURATION := 0.3
const SLIDING_SPEED := 256.0
const SLIDING_ENERGY := 4.0


var default_gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var run_speed := 166.0
var jump_velocity := -288.0
var 地面加速度 := run_speed/0.2
var 空中加速度 := run_speed/0.1
var GROUND_STATE := [State.IDLE , State.RUN] #, State.ATTACK1 , State.ATTACK2 , State.ATTACK3]
var is_first_tick := false
var walljump_velocity := Vector2(380 , -283)
var is_combo_requested := false



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		可跳跃Timer.start()
	if event.is_action_released("jump"):
		可跳跃Timer.stop()
		if velocity.y < jump_velocity / 2:
			velocity.y = jump_velocity / 2
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true
	
func tick_physics(state: State,delta: float) -> void: #与该状态相关的物理逻辑
	match state:
		State.IDLE:
			move(default_gravity , delta)
		State.RUN:
			move(default_gravity , delta)
		State.JUMP:
			move( 0 if is_first_tick else default_gravity , delta)
		State.FALL:
			move(default_gravity , delta)
		State.SLID:
			move(default_gravity /99.9 , delta)
		State.WALLJUMP:
			if state_machine.state_time < 0.1:
				stand(0 if is_first_tick else default_gravity , delta)
				动画node_2d.scale.x = get_wall_normal().x
			else:
				move(default_gravity , delta)
		State.ATTACK1, State.ATTACK2, State.ATTACK3:
			stand(default_gravity, delta)
		State.DOWN:
			stand(default_gravity , delta)
		State.SLIDING_END:
			stand(default_gravity, delta)
		
		State.SLIDING_START, State.SLIDING_LOOP:
			slide(delta)
		State.ROLL:
			slide(delta)
	is_first_tick = false
	
func move(gravity: float,delta: float) -> void:
	var direction := Input.get_axis("left" , "right")
	var 加速度 := 地面加速度 if is_on_floor() else 空中加速度
	velocity.x = move_toward(velocity.x , direction * run_speed , 加速度 * delta)
	velocity.y += gravity * delta
	
	
	if not is_zero_approx(direction):
		动画node_2d.scale.x = -1 if direction < 0 else +1
	move_and_slide()

func stand(gravity: float, delta: float) -> void:
	var 加速度 := 地面加速度 if is_on_floor() else 空中加速度
	velocity.x = move_toward(velocity.x , 0.0 , 加速度 * delta)
	velocity.y += gravity * delta
	move_and_slide()
func slide(delta: float) -> void:
	velocity.x = 动画node_2d.scale.x * SLIDING_SPEED
	velocity.y += default_gravity * delta
	
	move_and_slide()
#func can_wall_slide() -> bool:
	#return is_on_wall() and 手_ray_cast_2d.is_colliding() and 脚_ray_cast_2d.is_colliding()
	
func get_next_state(state: State) -> State: #状态转换逻辑条件函数
	var can_jump := is_on_floor() or 郊狼Timer.time_left > 0
	var 起跳条件 :=  can_jump and 可跳跃Timer.time_left > 0 #可跳跃Timer.time_left > 0 替代按下跳跃键
	if 起跳条件:
		return State.JUMP
	if state in GROUND_STATE and not is_on_floor():
		return State.FALL
	var direction := Input.get_axis("left" , "right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("slide"):
				return State.SLIDING_START
			if Input.is_action_just_pressed("roll"):
				return State.ROLL
			if not is_on_floor():
				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if not is_still:
				return State.RUN
			if Input.is_action_just_pressed("down"):
				return State.DOWN
		State.RUN:
			if Input.is_action_just_pressed("slide"):
				return State.SLIDING_START
			if Input.is_action_just_pressed("roll"):
				return State.ROLL
			if not is_on_floor():
				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if  is_still:
				return State.IDLE
			if Input.is_action_just_pressed("down"):
				return State.DOWN
			
		State.JUMP:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if velocity.y >= 0:
				return State.FALL
		State.FALL:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if is_on_floor():
				return State.RUN
			#if can_wall_slide():
				#return State.SLID
		State.SLID:
			if 可跳跃Timer.time_left > 0:
				return State.WALLJUMP
			if not is_on_wall():
				return State.FALL 
			
		State.WALLJUMP:
			#if can_wall_slide() and not is_first_tick:
				#return State.SLID
			if velocity.y >= 0:
				return State.FALL
		State.ATTACK1:
			if not animation_player.is_playing():
				return State.ATTACK2 if is_combo_requested else State.IDLE
		State.ATTACK2:
			if not animation_player.is_playing():
				return State.ATTACK3 if is_combo_requested else State.IDLE
		State.ATTACK3:
			if not animation_player.is_playing():
				return State.IDLE
		State.DOWN:
			if Input.is_action_just_released("down"):
				return State.IDLE
		State.SLIDING_START:
			if not animation_player.is_playing():
				return State.SLIDING_LOOP
		
		State.SLIDING_END:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_LOOP:
			if state_machine.state_time > SLIDING_DURATION or is_on_wall():
				return State.SLIDING_END
		State.ROLL:
			if not animation_player.is_playing():
				return State.IDLE
	return state

func transition_state(from: State, to: State) -> void: #各状态的各种执行代码
	if from not in GROUND_STATE and to in GROUND_STATE:
		郊狼Timer.stop()
	match to:
		State.IDLE:
			animation_player.play("idle")
		State.RUN:
			animation_player.play("run")
			#$"音效/AudioStreamPlayer4".play()
		State.DOWN:
			animation_player.play("down")
		State.JUMP:
			$"音效/AudioStreamPlayer3".play()
			animation_player.play("jump")
			velocity.y = jump_velocity 
			郊狼Timer.stop()
			可跳跃Timer.stop()
		State.FALL:
			$"音效/AudioStreamPlayer4".play()
			animation_player.play("fall")
			if from in GROUND_STATE:
				郊狼Timer.start()
		State.SLID:
			animation_player.play("slid")
		State.WALLJUMP:
			
			animation_player.play("jump")
			velocity = walljump_velocity
			velocity.x *= get_wall_normal().x
			可跳跃Timer.stop()
		State.ATTACK1:
			animation_player.play("attack1")
			is_combo_requested = false
			$"音效/AudioStreamPlayer".play()
		
		State.ATTACK2:
			animation_player.play("attack2")
			is_combo_requested = false
			$"音效/AudioStreamPlayer2".play()
		State.ATTACK3:
			animation_player.play("attack3")
			is_combo_requested = false
			$"音效/AudioStreamPlayer5".play()
		State.SLIDING_START:
			animation_player.play("sliding_start")
			#slide_request_timer.stop()
			#stats.energy -= SLIDING_ENERGY
		
		State.SLIDING_LOOP:
			animation_player.play("sliding_loop")
		
		State.SLIDING_END:
			animation_player.play("sliding_end")
		State.ROLL:
			animation_player.play("roll")
			$"音效/AudioStreamPlayer6".play()
	#if to == State.WALLJUMP:
		#Engine.time_scale = 0.3
	#if from == State.WALLJUMP:
		#Engine.time_scale = 1.0
	is_first_tick = true

