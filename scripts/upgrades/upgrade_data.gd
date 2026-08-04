extends Resource

signal modifier_applied(modifier: Resource)
signal modifier_removed(modifier: Resource)

@export var upgrade_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var max_stacks: int = 1
@export var applies_once: bool = false
@export var permanent: bool = false
@export var modifiers: Array = []
@export var mutual_exclusions: Array = []
@export var category: StringName = &"general"
