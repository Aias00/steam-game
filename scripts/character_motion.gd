extends RefCounted

# Four authored gait poses, advanced by actual distance rather than held keys.
const STRIDE_DISTANCE := 92.0
var phase := 0.0
var walking := false
var face_left := false

func advance(displacement: Vector2, dashing: bool, hurt: bool = false) -> void:
    if absf(displacement.x) > 0.01:
        face_left = displacement.x < 0
    walking = displacement.length_squared() > 0.0001 and not dashing and not hurt
    if walking:
        phase = fposmod(phase + displacement.length() / STRIDE_DISTANCE, 1.0)
    elif displacement.length_squared() <= 0.0001:
        phase = 0.0

func frame_index() -> int:
    return mini(3, int(phase * 4.0))
