extends Control

@onready var texture_rect = $VBoxContainer/PanelContainer/TextureRect
@onready var timeline = $VBoxContainer/Timeline
@onready var play_pause_button = $VBoxContainer/HBoxContainer/PlayPauseButton


var is_playing: bool = false


func _ready():
    play_pause_button.pressed.connect(on_play_pause_button_pressed)
    var video = Video.new()
    video.print_something("Hello")


func on_play_pause_button_pressed():
    is_playing = !is_playing
    if is_playing:
        pass
    else:
        pass
