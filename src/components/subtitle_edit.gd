class_name SubtitleEdit
extends CodeEdit

signal yield_focus
signal jump_to_here_requested(time: float)

var default_background_color: Color
var last_highlight_clip_index: int

var subtitle_track: SubtitleTrack = SubtitleTrack.new()
var subtitle_filepath: String:
    get:
        return subtitle_track.subtitle_filepath

@warning_ignore("integer_division")
func _ready():
    get_tree().root.files_dropped.connect(on_files_dropped)
    default_background_color = get_line_background_color(0)

    # 右键菜单
    var menu = get_menu()
    # Remove all items after "Redo".
    menu.item_count = menu.get_item_index(MENU_REDO) + 1
    menu.add_separator()
    # Bug? accl不起作用，还有参数类型warning。
    menu.add_item("Jump Play", MENU_MAX + 1)
    menu.add_item("Export ZH only", MENU_MAX + 2)
    menu.id_pressed.connect(func(id):
        match id:
            MENU_MAX + 1:
                jump_to_here_requested.emit(subtitle_track.subtitle_clips[get_caret_line() / 4].start_time)
                #if has_selection():
                    #Logger.debug("Selection: %s" % get_selected_text())
                    ## 从上往下选择，正常。从下往上选择，结果相同。
                    #Logger.debug("Selection from %d to %d" % [get_selection_line(), get_selection_to_line()])
                #select_all()
                #copy()
            MENU_MAX + 2:
                subtitle_track.export_subtitle_file(subtitle_filepath.replace(".ass", "_zh.ass"), true)
    )


func _gui_input(event):
    if event.is_action_pressed("ui_cancel"):
        yield_focus.emit()


func try_update(current_time: float):
    if subtitle_track and not subtitle_track.is_empty():
        subtitle_track.update(current_time)
        highlight_clip(subtitle_track.current_clip_index)
        set_line_as_center_visible(subtitle_track.current_clip_index * 4)


## 重新生成并手动分割，翻译的结果
func try_update_current_clip_with_clips(clips: Array[SubtitleClip]):
    if clips.size() == 0:
        return

    if subtitle_track and not subtitle_track.is_empty():
        var start_line = subtitle_track.current_clip_index * 4
        select(start_line, 0, start_line + 4, 0)
        delete_selection()
        clips.reverse()
        for clip in clips:
            insert_line_at(start_line, clip.full_edit_text().left(-1))

        subtitle_track.update_subtitle_clips(text)


func highlight_clip(clip_index: int):
    var lineno = clip_index * 4
    var last_lineno = last_highlight_clip_index * 4
    set_line_background_color(last_lineno, default_background_color)
    set_line_background_color(last_lineno+1, default_background_color)
    set_line_background_color(last_lineno+2, default_background_color)
    set_line_background_color(lineno, Color.DARK_OLIVE_GREEN)
    set_line_background_color(lineno + 1, Color.DARK_OLIVE_GREEN)
    set_line_background_color(lineno + 2, Color.DARK_OLIVE_GREEN)
    last_highlight_clip_index = clip_index


func load_subtitle_file(filepath: String):
    Config.set_app_value("subtitle_path", filepath)
    Logger.info("Subtitle Path: %s" % filepath)
    subtitle_track.load_subtitle_file(filepath)
    text = subtitle_track.get_full_text()


func save_subtitle_file(filepath: String = ""):
    if subtitle_track.num_clips == 0:
        return

    subtitle_track.update_subtitle_clips(text)

    if not filepath:
        filepath = subtitle_track.subtitle_filepath

    if filepath.ends_with("list"):
        filepath = Utils.get_parent_dir(Utils.get_parent_dir(filepath)) \
                    + "/video/" + Utils.get_stem(filepath) + ".ass"

    subtitle_track.export_subtitle_file(filepath)
    Logger.info("File Saved! %s!" % filepath)


func on_files_dropped(paths: Array):
    if not Utils.get_suffix(paths[0]) in "list, srt, ass":
        return

    if not get_global_rect().has_point(get_global_mouse_position()):
        return

    load_subtitle_file(paths[0].replace("\\", "/"))
