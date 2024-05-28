extends Control

const VIDEO_PATH = "D:/MyTools/BilinguSubs/assets/video/output/[1] Making a Video Player in Godot with FFmpeg - Tutorial.mp4"

@onready var texture_rect: TextureRect = $VBoxContainer/PanelContainer/TextureRect
@onready var timeline = $VBoxContainer/Timeline
@onready var play_pause_button = $VBoxContainer/HBoxContainer/PlayPauseButton
@onready var audio_stream_player = $AudioStreamPlayer


var video = Video.new()
var is_playing: bool = false
var dragging: bool = false

var max_frame: int = 0
var frame_rate: float = 0
var current_frame: int = 0

var elapsed_time: float = 0
var frame_time: float:
    get:
        return 1.0 / frame_rate


func _ready():
    play_pause_button.pressed.connect(on_play_pause_button_pressed)

    video.open_video(VIDEO_PATH)
    audio_stream_player.stream = video.get_audio()
    max_frame = video.get_total_frame_number()
    frame_rate = video.get_frame_rate()

    timeline.max_value = max_frame

    video.seek_frame(1)
    current_frame = 1


func _process(delta):
    if is_playing:
        elapsed_time += delta
        if elapsed_time < frame_time:
            return

        elapsed_time -= frame_time

        if !dragging:
            current_frame += 1

        if current_frame >= max_frame:
            video.seek_frame(1)
            current_frame = 1
            audio_stream_player.seek(0)
        else:
            texture_rect.texture.set_image(video.next_frame())

        if !dragging:
            timeline.value = current_frame


func on_play_pause_button_pressed():
    is_playing = !is_playing
    if is_playing:
        audio_stream_player.play(current_frame * frame_time)
    else:
        audio_stream_player.stream_paused = true


func _on_timeline_drag_ended(value_changed):
    dragging = false
    if !value_changed:
        return

    current_frame = timeline.value
    texture_rect.texture.set_image(video.seek_frame(current_frame))
    audio_stream_player.play(current_frame * frame_time)


func _on_timeline_drag_started():
    dragging = true
