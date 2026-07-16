extends Area2D

# 潛水員基礎速度（常態下是敵人的 1/2）
@export var base_speed: float = 90.0 

var direction: float = 1.0
var current_lane_y: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var rescue_sound: AudioStreamPlayer = $RescueSound

func _ready() -> void:
    animated_sprite.play("diver-move")
    current_lane_y = position.y
    # 💡 遊戲一開始，立刻執行一次轉世重置
    reset()

func _process(delta: float) -> void:
    if get_tree().has_group("player_dead_group"):
        if animated_sprite.is_playing():
            animated_sprite.stop()
        return
    else:
        animated_sprite.play()
    var current_speed = base_speed
    var current_direction = direction
    
    # 🚨 【AI 雷達】尋找同泳道是否有威脅
    var threat = _find_nearby_threat_in_lane()
    if threat != null:
        if threat.direction == current_direction:
            # 情況 A：同向 -> 速度加倍逃跑 (90 * 2 = 180)
            current_speed = base_speed * 2.0
        else:
            # 情況 B：相向 -> 立刻掉頭，且速度加倍
            current_direction = -direction
            current_speed = base_speed * 2.0
            
        animated_sprite.flip_h = (current_direction < 0)
    else:
        animated_sprite.flip_h = (direction < 0)

    # 沿著 X 軸前進
    position.x += current_speed * delta * current_direction
    position.y = current_lane_y
    
    # 【修改】出界不再 queue_free，而是像敵人一樣直接轉世重置！
    # 考慮到潛水員會掉頭，左側出界小於 -250 或右側出界大於 1500 就觸發重置
    if position.x > 1500 or position.x < -250:
        reset()

# --- 【修正後的群組雷達】 ---
func _find_nearby_threat_in_lane() -> Node2D:
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        var enemy_lane_y = enemy.get("current_lane_y")
        # 💡 關鍵修正：對比敵人的 current_lane_y（泳道中心點），無視鯊魚的上下起伏
        if enemy_lane_y!=null and abs(enemy.current_lane_y - current_lane_y) < 30.0:
            # 檢查水平距離是否在1/2個身位（30 像素）內
            var dist_x = abs(enemy.position.x - position.x)
            if dist_x < 60.0:
                return enemy
    return null

# --- 【全新：雅達利街機轉世機制】 ---
func reset() -> void:
    # 1. 尋找主場景中，跟自己待在同一個泳道的敵人
    var my_lane_enemy = _find_enemy_in_my_lane()
    
    if my_lane_enemy != null:
        # 💡 核心機制：潛水員出生時的方向，強行同步該泳道敵人的當前方向！
        # 這樣一來，只要兩者同時出生，就絕對會形成「前車與後車」的完美跟車隊形
        direction = my_lane_enemy.direction
    else:
        direction = 1.0 if randi() % 2 == 0 else -1.0
        
    # 2. 根據方向計算出生 X 座標（死死扣住 120 像素的 2 身位安全間距）
    var start_x: float = 0.0
    if direction > 0:
        start_x = -80 - 120  # 右行：標準出生點在 -200 像素處
        animated_sprite.flip_h = false
    else:
        start_x = 1356 + 120 # 左行：標準出生點在 1476 像素處
        animated_sprite.flip_h = true
        
    # 3. 🧠【街機靈魂小技巧：利用「深海埋伏」來模擬隨機定時器】
    # 如果每一輪出界都立刻出現在螢幕邊緣，畫面上永遠會有 4 個潛水員，太擠了！
    # 我們不使用 Timer 節點，而是隨機讓潛水員退到「更深的場外 X 座標」去埋伏。
    if randf() < 0.4: 
        # 有 40% 的機率，潛水員不留著這一班車，讓他往後退 500 到 1000 像素
        # 他會在很遠的場外慢慢游，過一陣子才會進入畫面，完美模擬了隨機生成率！
        var extra_delay_dist = randf_range(500.0, 1000.0)
        position.x = start_x - (extra_delay_dist * direction)
    else:
        # 60% 機率，緊跟在敵人後面出發
        position.x = start_x
        
    # 4. 歸位泳道 Y 軸
    position.y = current_lane_y

# 輔助函數：精準綁定同泳道的老鄰居
func _find_enemy_in_my_lane() -> Node2D:
    var enemies = get_tree().get_nodes_in_group("enemies")
    
    for enemy in enemies:
        var enemy_lane_y = enemy.get("current_lane_y")
        if enemy_lane_y!=null and abs(enemy_lane_y - current_lane_y) < 60.0:
            return enemy
    return null

func _on_area_entered(area: Area2D) -> void:
    if area.name.begins_with("Torpedo") or area.name.begins_with("torpedo"):
        area.queue_free()
        print("糟糕！你誤擊了潛水員！")
        # 【修改】誤傷後不 queue_free，直接原地轉世重置
        call_deferred("reset")

func _on_body_entered(body: Node2D) -> void:
    if body.name == "Player" or body.name.begins_with("Player") or body.is_in_group("player"):
        if body.has_method("add_rescued_diver"):
            var rescue_success = body.add_rescued_diver()
            if rescue_success:
                # 没到6个人
                if rescue_sound:
                    rescue_sound.play()
                print("🎉 成功營救潛水員！獲得救助積分！")
                # 【修改】營救成功後不 queue_free，直接原地轉世重置
                call_deferred("reset")
            else:
                #满了
                pass
            
