extends Node2D

export (int) var health;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass;

func take_damage(damage):
	health -= damage;
	# Can add damage effect here (explosions, etc.)
