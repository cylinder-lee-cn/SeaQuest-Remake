extends Area2D

@export var speed: float = 320.0
# 1.0 代表向右飛，-1.0 代表向左飛
var direction: float = 1.0 

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    
    # 根據最終方向，決定魚雷圖片是否需要翻轉
    # 因為魚雷預設也是向右，所以方向為左（-1.0）時需要翻轉
    if direction < 0:
        $Sprite2D.flip_h = true
    else:
        $Sprite2D.flip_h = false

func _physics_process(delta: float) -> void:
    position.x += speed * direction * delta

func _on_body_entered(body: Node2D) -> void:
    # 只要撞到的物體名字叫 Player，或者開頭是 Player
    if body.name == "Player" or body.name.begins_with("Player"):
        if body.has_method("die"):
            body.call_deferred("die")
        queue_free()

# 連結自 VisibleOnScreenNotifier2D 的信號
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
    queue_free()
