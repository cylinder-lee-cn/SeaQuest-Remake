extends Area2D

@export var speed: float = 2000.0 # 鱼雷飞行速度
var direction: float = 1.0       # 1.0 表示向右，-1.0 表示向左

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.

func _process(delta: float) -> void:
    # 根据方向乘以速度
    position.x += speed * direction * delta

    # 如果飞出屏幕边界（左侧0以外或右侧1276以外），自动销毁
    if position.x > 1350 or position.x < -100:
        queue_free()
