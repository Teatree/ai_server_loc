extends Resource

enum Operation {
	ADD,
	MULTIPLY,
	SET,
	ADD_PERCENT
}

@export var stat: StringName = &"health_max"
@export var value: float = 0.0
@export var operation: int = Operation.ADD
@export var target: StringName = &"player"
