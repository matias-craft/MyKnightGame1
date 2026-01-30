extends AnimatedSprite2D

func _ready():
	stop() # Don't play the animation, stay on the captured frame
	
	var tween = get_tree().create_tween()
	# Fade out the alpha over 0.3 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.finished.connect(queue_free)
