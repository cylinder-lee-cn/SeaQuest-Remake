extends Node2D

# 獲取氧氣條節點的引用（請根據你實際的節點名稱修改）
@onready var oxygen_bar: TextureProgressBar = %OxygenBar

# 【精確 30 秒倒計時設定】
@export var max_oxygen: float = 40.0 # 完整長度代表 30 秒
var current_oxygen: float = 40.0

# 消耗速度：設為 1.0 代表每秒精確扣除 1 秒的氧氣量
@export var oxygen_drain_speed: float = 1.0 

func _ready() -> void:
    pass
func _process(_delta: float) -> void:
    if get_tree().has_group("player_dead_group"):
        return
