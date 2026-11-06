extends RefCounted

var api: Object
var connected := false
var status := "OFFLINE MODE  /  Steam not installed or running"

func initialize() -> void:
    if "--offline" in OS.get_cmdline_user_args():
        status = "OFFLINE MODE  /  Steam disabled for this session"
        return
    if not Engine.has_singleton("Steam"):
        status = "OFFLINE MODE  /  Open with GodotSteam to connect"
        return
    api = Engine.get_singleton("Steam")
    # App ID 480 is Valve's shared test app. Replace it before release.
    var result: Dictionary = api.steamInitEx(480, false)
    connected = result.get("status", -1) == 0
    if connected:
        status = "STEAM CONNECTED  /  " + str(api.getPersonaName())
    else:
        status = "OFFLINE MODE  /  " + str(result.get("verbal", "Steam unavailable"))
    print("Steam initialization: ", result)

func poll() -> void:
    if connected:
        api.run_callbacks()
