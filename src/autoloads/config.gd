extends Node

const CONFIG_FILE_PATH = "user://settings.cfg"

var config: ConfigFile


func _ready():
    config = ConfigFile.new()
    if FileAccess.file_exists(CONFIG_FILE_PATH):
        var err = config.load(CONFIG_FILE_PATH)
        if err != OK:
            Logger.info("Config File Load error %d" % err)
    else:
        create_default_settings()
        config.save(CONFIG_FILE_PATH)


func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        config.save(CONFIG_FILE_PATH)
        Logger.info("Config Saved!")


func create_default_settings():
    config.set_value("App", "translate_api", "qwen")


func set_app_value(key: String, value):
    config.set_value("App", key, value)
    if "path" in key:
        EventBus.filepath_updated.emit()


func get_app_value(key: String):
    return config.get_value("App", key)
