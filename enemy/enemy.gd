extends Area2D

const ENEMY_TORPEDO = preload("res://enemy/enemy_torpedo.tscn")

# 還原原版比例的基礎速度 (180 像素/秒)
@export var base_speed: float = 180.0
# 【波浪設定】
@export var wave_amplitude: float = 15.0 # 波浪起伏的高度
@export var wave_frequency: float = 5.0  # 波浪游動的頻率

var current_type: String = "shark"
var direction: float = 1.0
var current_lane_y: float = 0.0
# 累加時間，用來計算正弦波
var time_passed: float = 0.0

# --- 【徹底重構：最安全的街機距離計數器】 ---
var distance_accumulator: float = 0.0  # 潛艇自己累計游過了多少像素
var is_torpedo_on_screen: bool = false # 自己发射魚雷是否存在

## --- 【新增：敵潛艇射擊限制變數】 ---
@onready var animated_sprite:  = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle # 【新增】發射點引用

# 【關鍵：獲取兩個獨立的音效節點引用】
@onready var shark_hit: AudioStreamPlayer2D = $SharkHit
@onready var sub_hit: AudioStreamPlayer2D = $SubHit

func _ready() -> void:
    current_lane_y = position.y
    reset()

func _process(delta: float) -> void:
    # 【關鍵新增】檢查場景樹中是否存在玩家死亡的群組
    if get_tree().has_group("player_dead_group"):
        if animated_sprite.is_playing():
            animated_sprite.stop()
        return
    else:
        animated_sprite.play()
        
    # 1. 沿著 X 軸前進
    var move_amount= base_speed * delta
    position.x += move_amount * direction
   
    # 2. 如果是鯊魚，計算波浪式前進效果
    if current_type == "shark":
        time_passed += delta
        # 使用 sin 函數計算上下起伏，並加到原本的泳道 Y 座標上
        position.y = current_lane_y + sin(time_passed * wave_frequency) * wave_amplitude
    else:
        # 敵潛艇保持直線
        position.y = current_lane_y
        # --- 【核心新增：敵潛艇射擊行為】 ---
        # A. 檢查是否走過 3 倍身長（204 像素）
        # --- 【核心修正】改用 Muzzle 的全域 X 座標來計算移動距離 ---
        distance_accumulator+=move_amount
        var has_moved_enough=(distance_accumulator>=204.0)
        # B. 檢查上一發魚雷是否已經消失
        var can_shoot_new_torpedo = not is_torpedo_on_screen
        if has_moved_enough and can_shoot_new_torpedo:
            shoot_torpedo()
       
    # 4. 出界即重置
    if (direction > 0 and position.x > 1350) or (direction < 0 and position.x < -100):
        reset()
        
# 【新增：發射敵魚雷函數】
func shoot_torpedo() -> void:
    force_update_transform()
    if muzzle:
        muzzle.force_update_transform()
    var torpedo = ENEMY_TORPEDO.instantiate()
    
    # 精確從調整後的 Muzzle 全域座標發射（在艦艏前方）
    torpedo.position = muzzle.global_position
    # 將當前前進方向（1.0 或 -1.0）傳遞給魚雷
    torpedo.direction = direction
    
    is_torpedo_on_screen=true
    torpedo.tree_exited.connect(_on_my_torpedo_destroyed)
    get_tree().current_scene.call_deferred("add_child", torpedo)
    
    distance_accumulator=0.0
func _on_my_torpedo_destroyed() -> void:
    is_torpedo_on_screen = false
    
# 【完美適配 68x30 與 68x48 尺寸的重置機制】
func reset() -> void:
    # 每次重置時，給一個隨機初始時間，讓每條泳道的鯊魚波浪錯開
    time_passed = randf() * 2.0 
    distance_accumulator=0.0
    is_torpedo_on_screen = false
    
    var new_shape = RectangleShape2D.new()
    
    # 1. 隨機決定是鯊魚還是敵潛艇
    if randf() < 0.5:
        current_type = "shark"
        animated_sprite.play("shark-move")
        new_shape.size = Vector2(68, 30)
    else:
        current_type = "sub"
        animated_sprite.play("enemysub-move")
        new_shape.size = Vector2(68, 48)
    # 💡 隨機一個初始幀，讓不同泳道的雜魚動作錯開，看起來更自然
    animated_sprite.frame = randi() % 6    
    # 將動態調整完的精確形狀賦予碰撞節點
    collision_shape_2d.shape = new_shape
        
    # 2. 隨機決定出生方向
    if randi() % 2 == 0:
        direction = 1.0
        position.x = -80              
        animated_sprite.flip_h = false
        if muzzle:
            muzzle.position.x = 34.0 # 硬編碼相對位置，安全可靠
    else:
        direction = -1.0
        position.x = 1356             
        animated_sprite.flip_h = true
        if muzzle:
            muzzle.position.x = -34.0 # 鏡像相對位置，安全可靠
    # 3. 初始化位置
    position.y = current_lane_y
    # 【核心修正】讓新出生的潛艇與 Muzzle 座標在這一幀內立刻死死綁定在出生點
    if muzzle:
        muzzle.force_update_transform()

func destroy_enemy() -> void:
    var player= get_tree().current_scene.find_child("Player",true,false)
    if player and player.has_method("add_score"):
        player.add_score(20)
        
# 【在此處精確定義 _on_area_entered 函數，解決報錯】
func _on_area_entered(area: Area2D) -> void:
    # 檢查撞上來的是不是玩家發射的魚雷（根據節點名稱判斷）
    if area.name.begins_with("Torpedo") or area.name.begins_with("torpedo"):
        # 讓魚雷本身消失销毁
        area.queue_free()
        destroy_enemy()
        
        if current_type == "shark":
            shark_hit.play()
        else:
            sub_hit.play()
        # 觸發雅達利轉世機制，原地重置為新敵人
        call_deferred("reset")
        
# 【情況 B：當撞上來的是 CharacterBody2D（玩家潛艇本體）】
func _on_body_entered(body: Node2D) -> void:
    # 檢查撞上來的是不是玩家 (Player)
    if body.name == "Player" or body.name.begins_with("Player"):
        # 觸發玩家死亡邏輯
        # 這裡可以直接調用玩家腳本裡的死亡函數（如果玩家有寫的話）
        if body.has_method("die"):
            body.die()
        else:
            # 如果目前玩家還沒寫死亡函數，我們可以先讓玩家消失，或重啟場景來模擬死亡
            print("玩家被撞死了！")
            body.queue_free() # 暫時直接讓玩家消失（正式開發時建議用自訂函數處理扣血、播動畫）
