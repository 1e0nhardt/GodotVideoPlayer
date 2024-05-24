extends Control

const VIDEO_PATH = "D:/MyTools/BilinguSubs/assets/video/output/[1] Making a Video Player in Godot with FFmpeg - Tutorial.mp4"

@onready var texture_rect: TextureRect = $VBoxContainer/PanelContainer/TextureRect
@onready var timeline = $VBoxContainer/Timeline
@onready var play_pause_button = $VBoxContainer/HBoxContainer/PlayPauseButton


var video = Video.new()
var is_playing: bool = false


func _ready():
    play_pause_button.pressed.connect(on_play_pause_button_pressed)
    var start_time: int = Time.get_ticks_usec()
    video.open_video(VIDEO_PATH)
    texture_rect.texture.set_image(video.seek_frame(400))
    print("Total frame number: %s" % video.get_total_frame_number())
    #$AudioStreamPlayer1.stream = video.get_audio()
    print("Timecost of Load Video: %d us" % (Time.get_ticks_usec() - start_time))
    #print($AudioStreamPlayer1.stream.get_length())
    #$AudioStreamPlayer1.play()


func _process(_delta):
    if is_playing:
        texture_rect.texture.set_image(video.next_frame())


func on_play_pause_button_pressed():
    is_playing = !is_playing
    if is_playing:
        pass
    else:
        pass
