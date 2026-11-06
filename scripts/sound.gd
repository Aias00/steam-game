extends Node

var muted := false
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var shot_clock := 0.0
var sounds: Dictionary = {}

func _ready() -> void:
    for index in range(6):
        var voice := AudioStreamPlayer.new()
        voice.volume_db = -19
        add_child(voice)
        voices.append(voice)
    for spec in [["shot", 620.0, 0.045], ["pickup", 1040.0, 0.05], ["hurt", 115.0, 0.14],
        ["upgrade", 820.0, 0.22], ["nova", 190.0, 0.22], ["dash", 370.0, 0.09],
        ["boss", 90.0, 0.5], ["boss_down", 950.0, 0.4], ["won", 1100.0, 0.4], ["lost", 130.0, 0.5]]:
        sounds[spec[0]] = tone(spec[1], spec[2])

func _process(delta: float) -> void:
    shot_clock = maxf(0, shot_clock - delta)

func play_event(key: String) -> void:
    if muted or not sounds.has(key) or voices.is_empty():
        return
    if (key == "shot" or key == "pickup") and shot_clock > 0:
        return
    if key == "shot" or key == "pickup":
        shot_clock = 0.08
    voices[cursor].stream = sounds[key]
    voices[cursor].play()
    cursor = (cursor + 1) % voices.size()

func tone(frequency: float, duration: float) -> AudioStreamWAV:
    var data := PackedByteArray()
    var count := int(22050 * duration)
    data.resize(count * 2)
    for index in range(count):
        var time := float(index) / 22050
        var envelope := minf(time * 200, 1) * pow(1.0 - float(index) / count, 2)
        var sample := int(sin(TAU * frequency * time * (1.0 - time * 0.6)) * envelope * 12000)
        data.encode_s16(index * 2, sample)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    return stream
