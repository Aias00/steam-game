extends SceneTree
const Motion = preload("res://scripts/character_motion.gd")
func _initialize() -> void:
    var motion = Motion.new()
    motion.advance(Vector2.ZERO, false)
    assert(not motion.walking and motion.frame_index() == 0)
    for index in range(4):
        motion.advance(Vector2(23, 0), false)
        assert(motion.walking and motion.frame_index() == (index + 1) % 4)
    motion.advance(Vector2(-23, 0), false)
    assert(motion.face_left and motion.frame_index() == 1)
    motion.advance(Vector2(0, -23), false)
    assert(motion.face_left and motion.frame_index() == 2)
    var before: float = motion.phase
    motion.advance(Vector2(20, 0), true)
    assert(not motion.walking and motion.phase == before)
    motion.advance(Vector2(20, 0), false, true)
    assert(not motion.walking and motion.phase == before)
    motion.advance(Vector2.ZERO, false)
    assert(not motion.walking and motion.phase == 0)
    var slow = Motion.new()
    var fast = Motion.new()
    for n in range(10):
        slow.advance(Vector2(2.3, 0), false)
    fast.advance(Vector2(23, 0), false)
    assert(is_equal_approx(slow.phase, fast.phase))
    print("PASS: distance-based four-frame gait, idle/wall stop, dash/hurt exclusion, horizontal facing, frame-rate independent stride")
    quit()
