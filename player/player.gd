extends CharacterBody2D

@export var speed: float = 480.0 # 潜艇移动速度
@export var torpedo_scene: PackedScene = preload("res://player/torpedo.tscn") # 载入鱼雷场景

# 获取 Sprite2D 和 Muzzle 的引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var refill_sound: AudioStreamPlayer2D = $RefillSound

# 假設 DiverIcons 容器在玩家節點底下的 UI 畫布裡：
@onready var diver_icons_container: HBoxContainer = %DiverIcons
@onready var score_label: Label = %ScoreLabel
@onready var oxygen_bar: TextureProgressBar = %OxygenBar
@onready var player_icons_container: HBoxContainer = %PlayerIcons
@onready var game_over_screen: Label=%GameOverScreen
    
# 记录 Muzzle 初始的 X 坐标
var muzzle_default_x: float = 0.0
# 记录当前面对的方向：1 为右，-1 为左
var facing_direction: float = 1.0

# 【關鍵】用來儲存當前畫面上魚雷的實例
var current_torpedo: Node = null

# 標記玩家是否已經死亡，防止重複觸發死亡邏輯
var is_dead: bool = false
var lives: int = 3
var start_position: Vector2
# 營救計數器
var rescued_count: int = 0
const MAX_RESCUED: int = 6
# 用來儲存和控制閃爍動畫的變數
var flash_tween: Tween

var score: int = 0
@export var max_oxygen: float = 32.0
var current_oxygen: float = 32.0

const SURFACE_Y: float = 182.0
var is_at_surface: bool = false 

# 控制是否處於充氣中、是否為開局動畫
var is_refilling: bool = false
var is_intro: bool = false

func _ready() -> void:
    # 自动记录你在编辑器里摆放的 Muzzle X 轴位置
    muzzle_default_x = muzzle.position.x
    start_position=global_position
    current_oxygen=0.0
    oxygen_bar.max_value=max_oxygen
    oxygen_bar.value=max_oxygen
    animated_sprite.play("sub-move")
    update_diver_ui(0)
    update_score_ui()
    update_lives_ui()
    death_sound.finished.connect(_on_death_sound_finished)
    # 💡【新增】開局立刻啟動「定格充氣模式」
    is_refilling = true
    is_intro = true
    add_to_group("player_dead_group") # 借用這個群組，讓 main.gd 和敵人一網打盡全部定格！
    
func _process(delta: float) -> void:
    if is_dead: return
   
    if global_position.y <= SURFACE_Y:
        if not is_at_surface:
            is_at_surface = true
            handle_surfacing()
        is_refilling=true
        execute_oxygen_refill(delta)
    else:
        is_at_surface = false
        if is_refilling and not is_intro:
            is_refilling =false
            if refill_sound and refill_sound.playing:
                refill_sound.stop()
        if not is_intro:
            current_oxygen -= delta
            if current_oxygen <=0:
                current_oxygen=0
                die()
    update_oxygen_ui()
#充气函数
func execute_oxygen_refill(delta: float) -> void:
    if current_oxygen < max_oxygen:
        if refill_sound and not refill_sound.playing:
            refill_sound.play()
    #2秒充满
        current_oxygen += (max_oxygen /2.0) * delta
        if current_oxygen >= max_oxygen:
            current_oxygen=max_oxygen
            end_refill()
    update_oxygen_ui()
#充气完成后结算选择
func end_refill()     -> void:
    is_refilling=false
    if refill_sound and refill_sound.playing:
        refill_sound.stop()
    #如果是局，解放群组
    if is_intro:
        is_intro=false
        if is_in_group("player_dead_group"):
            remove_from_group("player_dead_group")
        print("🚀 開局充氣完成！全場解凍，遊戲開始！")
func handle_surfacing() -> void:
    if is_dead: return
    if rescued_count >= MAX_RESCUED:
        var total_diver_score = MAX_RESCUED*50
        var total_oxygen_score = int(current_oxygen)*50
        add_score(total_diver_score+total_oxygen_score)
        print("👑 完美滿載上浮！人數分：", total_diver_score, " | 氧氣分：", total_oxygen_score)
        rescued_count=0
    else:
        if rescued_count>0:
            rescued_count-=1
            print("🚨 警告：未滿6人強行上浮！扣除一名潛水員！剩餘：", rescued_count)
        else:
            print("⚓ 空載上浮，安全補給。")
    update_diver_ui(rescued_count)
    
func add_score(amount: int) -> void:
    score+=amount
    update_score_ui()

func update_score_ui() -> void:
    if score_label:
        score_label.text=str(score)

func update_oxygen_ui() -> void:
    if oxygen_bar:
        oxygen_bar.value = current_oxygen    
        
func update_lives_ui() -> void:
    var icon1= player_icons_container.get_node_or_null("player-icon1")
    var icon2= player_icons_container.get_node_or_null("player-icon2")
    if icon1: icon1.visible = (lives>=3)
    if icon2: icon2.visible = (lives>=2)
    
func _physics_process(_delta: float) -> void:
    # 如果玩家已經死了，就停止處理移動邏輯
    if is_dead or is_intro:
        return
    # 1. 获取方向键输入
    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    # 2. 计算并应用速度
    velocity = direction * speed
    move_and_slide()
    # 3. 限制潜艇不能超出屏幕边界 (1276 x 760)
    # 考虑了潜艇自身大小的一半（134x42），防止边缘出界
    position.x = clamp(position.x, 134, 1276 - 134)
    position.y = clamp(position.y, 182, 616 - 21)
    
# 4. 根据左右运动转向（只控制图片翻转和发射点位置，不影响根节点）
    if direction.x > 0:
        facing_direction = 1.0
        animated_sprite.flip_h = false          # 图片不翻转（面向右）
        muzzle.position.x = muzzle_default_x # 发射点在右边
    elif direction.x < 0:
        facing_direction = -1.0
        animated_sprite.flip_h = true           # 图片水平翻转（面向左）
        muzzle.position.x = -muzzle_default_x # 发射点镜像到左边

func _unhandled_input(event: InputEvent) -> void:
    if lives<=0 and is_dead:
        if event.is_action_pressed("ui_accept"):
            get_tree().reload_current_scene()
        return
    if is_dead or is_intro:
        return
    # 检测空格键开火
    if event.is_action_pressed("ui_accept"): 
        # 【關鍵】只有當 current_torpedo 為 null（代表上一發已消失）或者是無效節點時，才允許開火
        if not is_instance_valid(current_torpedo) and position.y > 182:
            fire_torpedo()
 
func fire_torpedo() -> void:
    # 实例化鱼雷
    var torpedo = torpedo_scene.instantiate()
    current_torpedo = torpedo
    # 设置鱼雷的初始位置为当前 Muzzle 的全局位置 (Global Position)
    torpedo.global_position = muzzle.global_position
    
    # 将潜艇当前的朝向传递给鱼雷
    torpedo.direction = facing_direction
    
    # 如果潜艇面向左，鱼雷的图片也需要翻转显示
    if facing_direction < 0:
        torpedo.scale.x = -1.0
    else:
        torpedo.scale.x = 1.0
        
    # 将鱼雷添加到主场景中
    get_parent().add_child(torpedo)
    #
    shoot_sound.play()
# 【關鍵新增：玩家死亡函數】

func die() -> void:
    if is_dead:
        return
    is_dead = true
    lives-=1
    update_lives_ui()
    print("玩家爆炸了！")
    # 【關鍵新增】將自己加入一個名為 "player_dead_group" 的群組，方便敵人識別狀態
    add_to_group("player_dead_group")
    # 1. 播放炸毀动画
    animated_sprite.play("sub-die")
    # 2. 播放死亡音效
    death_sound.play()

    if rescued_count>0:
        rescued_count-=1
        print("💔 死亡懲罰：遺失一名潛水員！剩餘：", rescued_count)
    update_diver_ui(rescued_count)

func _on_death_sound_finished() -> void:
    if lives>0:
        is_dead=false
        if not is_in_group("player_dead_group"):
            add_to_group("player_dead_group")
        animated_sprite.play("sub-move")
        current_oxygen=0.0
        is_refilling=true
        is_intro=true
        is_at_surface=true
        global_position=start_position
        print("🛸 潛艇已在海面復活！剩餘生命：", lives)
    else:
        print("💀 GAME OVER！所有生命已耗盡！")
        if game_over_screen:
            game_over_screen.visible=true   
        
# 修改原本的營救函數
func add_rescued_diver() -> bool:
    if rescued_count < MAX_RESCUED:
        rescued_count += 1
        print("🎉 營救成功！目前潛艇內人數：", rescued_count, " / ", MAX_RESCUED)
        
        update_diver_ui(rescued_count)
        
        return true # 回傳 true，代表成功救起
    else:
        print("🚨 潛艇已經滿載（6人）！裝不下了！請先浮上海面解救他們！")
        return false # 回傳 false，代表滿載拒收

func update_diver_ui(count: int) -> void:
    if not diver_icons_container: return
    
    for i in range(1,7):
        # 使用字串拼接動態獲取節點，完美避開「-」連字號的語法報錯
        var icon_name = "diver-icon" + str(i)
        var icon_node = diver_icons_container.get_node(icon_name) as TextureRect
        if icon_node:
            # 如果目前編號小於等於救到的人數，就顯示（true），否則隱藏（false）
            icon_node.visible = (i <= count)
    # 處理滿載 6 人的閃爍邏輯
    if count >= MAX_RESCUED:
        # 如果還沒有建立閃爍動畫，或者動畫已經失效，就建立一個新的
        if flash_tween == null or not flash_tween.is_valid():
            flash_tween = create_tween().set_loops() # 設定為無限循環
            
            # 0.2 秒內變成半透明紅色（充滿街機危機感）
            flash_tween.tween_property(diver_icons_container, "modulate", Color(1, 0.2, 0.2, 0.3), 0.2)
            # 0.2 秒內恢復正常的白色與全透明度
            flash_tween.tween_property(diver_icons_container, "modulate", Color(1, 1, 1, 1), 0.2)
    else:
        # 情況 B：人數低於 6 人（例如剛浮上水面把人放掉）
        # 必須立刻殺掉動畫，並把顏色強制還原，否則圖標可能會卡在半透明或紅色狀態
        if flash_tween and flash_tween.is_valid():
            flash_tween.kill() # 停止動畫
        
        diver_icons_container.modulate = Color(1, 1, 1, 1) # 完美復原        
