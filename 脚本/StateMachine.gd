class_name StateMachine #这定义了一个名为StateMachine的新类
extends Node

var current_state: int = -1: #定义了一个名为current_state的整数变量并初始化为-1。这个变量用于存储状态机的当前状态
	set(v):
		owner.transition_state(current_state,v) #状态转换时的执行代码
		current_state = v
		state_time = 0
var state_time : float

func _ready() -> void:
	await owner.ready
	current_state = 0
	
func _physics_process(delta: float) -> void:
	while true:
		var next := owner.get_next_state(current_state) as int #状态改变逻辑
		if current_state == next:
			break
		current_state = next
	owner.tick_physics(current_state,delta) #与该状态相关的物理逻辑
	state_time += delta
