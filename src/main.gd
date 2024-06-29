extends Control

const VIDEO_PATH := ""
const PATH_INFO_FROMAT := """[table=2]
[cell border=#fff3]视频路径[/cell][cell border=#fff3]%s[/cell]
[cell border=#fff3]音频路径[/cell][cell border=#fff3]%s[/cell]
[cell border=#fff3]字幕路径[/cell][cell border=#fff3]%s[/cell]
[/table]"""

@export var message_label_scene: PackedScene

@onready var video_canvas: TextureRect = %VideoCanvas
@onready var audio_stream_player = $AudioStreamPlayer
@onready var timeline = %Timeline
@onready var play_pause_button = %PlayPauseButton
@onready var speed_button = %SpeedButton
@onready var time_label = %TimeLabel
@onready var subtitle_edit: SubtitleEdit = %SubtitleEdit
@onready var save_subtitle_file_dialog = $SaveFileDialog
@onready var open_video_file_dialog = $OpenVideoFileDialog
@onready var hidden_menu_button = %HiddenMenuButton
@onready var subtitle_label = %SubtitleLabel
@onready var asr_popup_panel = %AsrPopupPanel
@onready var path_info_label = %PathInfoLabel
@onready var message_edit = %MessageEdit
@onready var message_type_option = %MessageTypeOption
@onready var message_container = %MessageContainer

var video = Video.new()
var has_video: bool = false
var is_playing: bool = false
var dragging: bool = false

var max_frame: int = 0
var raw_frame_rate: float = 0
var frame_rate: float = 0
var current_frame: int = 0:
    set(value):
        current_frame = value
        time_label.text = "%s/%s" % [
            Utils.time_float2str(current_frame / raw_frame_rate),
            Utils.time_float2str(max_frame / raw_frame_rate),
        ]
var current_time: float = 0:
    get:
        return current_frame / raw_frame_rate

var elapsed_time: float = 0
var frame_time: float:
    get:
        return 1.0 / frame_rate


func _ready():
    get_tree().root.files_dropped.connect(on_files_dropped)
    EventBus.subtitle_clip_index_updated.connect(on_subtitle_clip_index_updated)
    EventBus.filepath_updated.connect(on_filepath_updated)
    WS.qwen_call_once_completed.connect(on_qwen_call_once_completed)
    play_pause_button.pressed.connect(on_play_pause_button_pressed)
    speed_button.item_selected.connect(on_speed_item_selected)
    open_video_file_dialog.file_selected.connect(on_open_file)
    save_subtitle_file_dialog.file_selected.connect(func (filepath: String):
        subtitle_edit.save_subtitle_file(filepath.replace("\\", "/"))
    )

    # 编辑时暂停，按esc退出编辑，继续播放。
    subtitle_edit.focus_entered.connect(func(): pause_or_play(false))
    subtitle_edit.yield_focus.connect(func(): pause_or_play(true))
    subtitle_edit.jump_to_here_requested.connect(func(t):
        seek_time(t, true)
        pause_or_play(true)
    )

    # 设置菜单栏
    hidden_menu_button.get_popup().add_item("Open Video", 0, KEY_MASK_CTRL | KEY_O)
    hidden_menu_button.get_popup().add_item("Save Subtitle", 1, KEY_MASK_CTRL | KEY_S)
    hidden_menu_button.get_popup().add_item("Save Subtitle As", 2, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
    hidden_menu_button.get_popup().add_item("Quit", 3, KEY_MASK_CTRL | KEY_Q)
    hidden_menu_button.get_popup().id_pressed.connect(on_hidden_menu_id_pressed)

    open_video(VIDEO_PATH)

    WS.connect_to_python()


func _process(delta):
    if is_playing:
        elapsed_time += delta
        if elapsed_time < frame_time:
            return

        elapsed_time -= frame_time
        if !dragging:
            current_frame += 1
            subtitle_edit.try_update(current_time)

            if current_frame >= max_frame:
                is_playing = !is_playing
                video.seek_frame(1)
                current_frame = 1
                audio_stream_player.stream_paused = true
            else:
                video_canvas.texture.set_image(video.next_frame())

            timeline.value = current_frame


func open_video(filepath: String):
    if not filepath:
        return

    Config.set_app_value("video_path", filepath)
    Logger.info("Video Path: %s" % filepath)
    has_video = true
    # 寻找对应音频
    var possible_audio_path = Utils.get_parent_dir(Utils.get_parent_dir(filepath)) +\
                             "/audio/" + Utils.get_stem(filepath)
    if FileAccess.file_exists(possible_audio_path + ".m4a"):
        Config.set_app_value("audio_path", possible_audio_path + ".m4a")
        Logger.info("Audio Path: %s" % possible_audio_path + ".m4a")
    else:
        Config.set_app_value("audio_path", possible_audio_path + ".wav")
        Logger.info("Audio Path: %s" % possible_audio_path + ".wav")
    # 寻找对应ass
    var possiable_subtitle_path = Utils.get_parent_dir(filepath) + "/" + Utils.get_stem(filepath)
    if FileAccess.file_exists(possiable_subtitle_path + ".ass"):
        subtitle_edit.load_subtitle_file(possiable_subtitle_path + ".ass")

    Utils.reset_start_time()
    video.open_video(filepath)
    audio_stream_player.stream = video.get_audio()
    Utils.print_time_cost()
    max_frame = video.get_total_frame_number()
    raw_frame_rate = video.get_frame_rate()
    frame_rate = raw_frame_rate

    timeline.max_value = max_frame

    seek_frame(1)


func seek_frame(frame_number: int, flush_canvas=false):
    if not has_video:
        Logger.warn("No video opened yet!")
        return

    if flush_canvas:
        video.seek_frame(frame_number - 1)
        if frame_number <= max_frame:
            video_canvas.texture.set_image(video.next_frame())
    else:
        video.seek_frame(frame_number)
    current_frame = frame_number
    audio_stream_player.play(current_time)
    audio_stream_player.stream_paused = !is_playing
    timeline.set_value_no_signal(current_frame)


func seek_time(time: float, flush_canvas=false):
    seek_frame(int(time * raw_frame_rate), flush_canvas)


func pause_or_play(flag: bool):
    is_playing = flag
    if is_playing:
        audio_stream_player.play(current_frame * frame_time)

    audio_stream_player.stream_paused = !is_playing


func on_subtitle_clip_index_updated():
    var reg = RegEx.create_from_string(r"(?<!\w)( +)(?!\w)")
    if subtitle_edit.subtitle_track.num_clips != 0:
        subtitle_label.text = reg.sub(subtitle_edit.subtitle_track.current_clip.first_text, "\n")
        %SubtitleLabel2.text = subtitle_edit.subtitle_track.current_clip.second_text
    #subtitle_label.text = subtitle_edit.subtitle_track.current_clip.first_text.replace(reg, "\n")


func on_play_pause_button_pressed():
    pause_or_play(!is_playing)


func _on_timeline_drag_ended(_value_changed):
    dragging = false
    seek_frame(timeline.value)


func _on_timeline_drag_started():
    dragging = true
    audio_stream_player.stream_paused = true


func on_speed_item_selected(id: int):
    var play_speed = float(speed_button.get_item_text(id))
    Logger.info("Play Speed: %s" % play_speed)
    frame_rate = raw_frame_rate * play_speed
    #TODO video bus
    var pitch_shift = AudioEffectPitchShift.new()
    pitch_shift.pitch_scale = 1.0 / play_speed
    AudioServer.playback_speed_scale = play_speed
    while AudioServer.get_bus_effect_count(0) > 0:
        AudioServer.remove_bus_effect(0, 0)
    AudioServer.add_bus_effect(0, pitch_shift)


func on_files_dropped(paths: Array):
    if not Utils.get_suffix(paths[0]) in "mp4, mkv, flv, mov":
        return

    if not video_canvas.get_global_rect().has_point(get_global_mouse_position()):
        return

    open_video(paths[0].replace("\\", "/"))


func on_open_file(filepath: String):
    filepath = filepath.replace("\\", "/")
    var suffix = Utils.get_suffix(filepath)
    if suffix in "mp4, mkv, flv":
        open_video(filepath)
    elif suffix in "mp3, m4a":
        #TODO 指定后端待处理音频
        pass
    elif suffix in "ass":
        subtitle_edit.load_subtitle_file(filepath)


func on_filepath_updated():
    var new_text = PATH_INFO_FROMAT % [
        Config.get_app_value("video_path"),
        Config.get_app_value("audio_path"),
        Config.get_app_value("subtitle_path"),
    ]
    path_info_label.text = new_text


func on_hidden_menu_id_pressed(id: int):
    match id:
        0: open_video_file_dialog.popup()
        1:
            subtitle_edit.save_subtitle_file()
            EventBus.subtitle_clip_index_updated.emit()
        2: save_subtitle_file_dialog.popup()
        3: get_tree().quit()


#region SubtitleEdit Buttons
func _on_next_clip_button_pressed():
    seek_time(subtitle_edit.subtitle_track.next_clip_start_time + 0.1, true)
    subtitle_edit.try_update(current_time)


func _on_prev_clip_button_pressed():
    seek_time(subtitle_edit.subtitle_track.prev_clip_start_time + 0.1, true)
    subtitle_edit.try_update(current_time)


func _on_combine_next_button_pressed():
    subtitle_edit.subtitle_track.merge_with_next_clip()
    subtitle_edit.text = subtitle_edit.subtitle_track.get_full_text()
    subtitle_edit.try_update(current_time)


func _on_goto_next_long_sentence_button_pressed():
    var target_index = subtitle_edit.subtitle_track.get_next_long_sentence_index()
    if target_index == -1:
        return
    else:
        subtitle_edit.subtitle_track.current_clip_index = target_index
        seek_time(subtitle_edit.subtitle_track.current_clip.start_time + 0.1, true)
        subtitle_edit.try_update(current_time)


func _on_reasr_button_pressed():
    if subtitle_edit.subtitle_track.num_clips == 0:
        return

    WS.send({
        "type": "asr",
        "payload": {
            "audio_path": Config.get_app_value("audio_path"),
            "time_range": subtitle_edit.subtitle_track.current_clip.get_clip_time_range()
        }
    })
    %AsrEdit.raw_clip_first_text = subtitle_edit.subtitle_track.current_clip.first_text
    asr_popup_panel.show()


func _on_asr_popup_cancel_button_pressed():
    asr_popup_panel.hide()


func _on_confirm_btton_pressed():
    asr_popup_panel.hide()
    subtitle_edit.try_update_current_clip_with_clips(%AsrEdit.asr_words.clips)
#endregion


func _on_send_button_pressed():
    WS.send({
        "type": "qwen_call_once",
        "payload": message_edit.text
    })
    var msg_label_instance := message_label_scene.instantiate() as RichTextLabel
    msg_label_instance.text = message_edit.text
    message_container.add_child(msg_label_instance)
    message_edit.text = ""


func on_qwen_call_once_completed(result: String):
    var msg_label_instance := message_label_scene.instantiate() as RichTextLabel
    msg_label_instance.text = result
    message_container.add_child(msg_label_instance)


func _on_message_edit_text_submitted(_new_text):
    _on_send_button_pressed()


func _on_conbine_pressed() -> void:
    # 分割工具的合并按钮
    var raw_content = %RawTextEdit.text.strip_edges()
    var page_num = %RawTextEdit.curr_page_num
    var page_size = %RawTextEdit.page_size
    var translated_content = %TranslatedTextEdit.text.strip_edges()

    if raw_content == "" or translated_content == "":
        return

    var combined_clips: Array[SubtitleClip] = []
    var reg = RegEx.create_from_string(r"\[(.*)->(.*)\](.*)")
    var reg_match: RegExMatch

    var raw_lines = raw_content.split("\n")
    var translated_lines = translated_content.split("\n")

    if raw_lines.size() != translated_lines.size():
        Logger.warn("翻译结果数量不匹配! %d!=%d" % [raw_lines.size(), translated_lines.size()])
        return

    for i in raw_lines.size():
        var subtitle_clip = SubtitleClip.new()
        reg_match = reg.search(raw_lines[i])
        if reg_match:
            subtitle_clip.start = Utils.time_float2str(float(reg_match.get_string(1)))
            subtitle_clip.end = Utils.time_float2str(float(reg_match.get_string(2)))
            subtitle_clip.second_text = reg_match.get_string(3)
        else:
            Logger.warn("Invalid line! => %s" % raw_lines[i])

        reg_match = reg.search(translated_lines[i])
        if reg_match:
            subtitle_clip.first_text = reg_match.get_string(3)
        else:
            Logger.warn("Invalid line! => %s" % translated_lines[i])
        combined_clips.append(subtitle_clip)

    for i in combined_clips.size():
        subtitle_edit.subtitle_track.subtitle_clips[page_num * page_size + i] = combined_clips[i]
    subtitle_edit.text = subtitle_edit.subtitle_track.get_full_text()
    subtitle_edit.save_subtitle_file()

    seek_time(combined_clips[0].start_time + 0.1, true)
