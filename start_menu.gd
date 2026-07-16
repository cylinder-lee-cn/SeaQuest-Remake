extends Control

@export var game_scene_path: String = "res://main/main.tscn"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var start_sound: AudioStreamPlayer2D = $StartSound
var is_starting: bool = false # 防止玩家瘋狂連按空格鍵重複觸發

func _ready() -> void:
    pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
    pass

func _unhandled_input(event: InputEvent) -> void:
    # 監聽玩家按下空格鍵（ui_accept）
    if event.is_action_pressed("ui_accept") and not is_starting:
        print("🚀 玩家按下空格，切換至遊戲主場景！")
        is_starting=true
        if start_sound:
            start_sound.play()
        start_game_flow()

func start_game_flow() -> void:
    print("播放黑屏转场")
    animation_player.play("fade_to_black")
    await animation_player.animation_finished
    print("播放完成")
    # 絲滑切換到你的主遊戲場景
    get_tree().change_scene_to_file(game_scene_path)
