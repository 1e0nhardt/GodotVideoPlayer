extends Control

const VIDEO_PATH = "D:/MyTools/BilinguSubs/assets/video/output/[1] Making a Video Player in Godot with FFmpeg - Tutorial.mp4"

@onready var texture_rect = $VBoxContainer/PanelContainer/TextureRect
@onready var timeline = $VBoxContainer/Timeline
@onready var play_pause_button = $VBoxContainer/HBoxContainer/PlayPauseButton


var video = Video.new()
var is_playing: bool = false


func _ready():
    play_pause_button.pressed.connect(on_play_pause_button_pressed)
    video.open_video(VIDEO_PATH)
    var start_time: int = Time.get_ticks_usec()
    $AudioStreamPlayer1.stream = video.get_audio()
    print("Timecost of Load Audio: %d us" % (Time.get_ticks_usec() - start_time))
    print($AudioStreamPlayer1.stream.get_length())
    $AudioStreamPlayer1.play()


func on_play_pause_button_pressed():
    is_playing = !is_playing
    if is_playing:
        pass
    else:
        pass
