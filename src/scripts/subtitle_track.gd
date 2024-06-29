class_name SubtitleTrack
extends Object

var subtitle_filepath: String = "temp.ass"
var subtitle_clips: Array[SubtitleClip]
var current_clip_index: int = -1:
    set(value):
        current_clip_index = value
        EventBus.subtitle_clip_index_updated.emit()
var current_clip: SubtitleClip:
    get:
        if is_empty():
            return null
        return subtitle_clips[current_clip_index]
var num_clips: int:
    get:
        return subtitle_clips.size()

var prev_clip_start_time: float:
    get:
        if is_empty():
            return 0
        return subtitle_clips[max(0, current_clip_index - 1)].start_time
var next_clip_start_time: float:
    get:
        if is_empty():
            return 0
        return subtitle_clips[min(num_clips, current_clip_index + 1)].start_time


## 加载字幕文件
func load_subtitle_file(filepath: String):
    subtitle_filepath = filepath
    subtitle_clips = Utils.parse_subtitle_file(filepath)
    current_clip_index = 0
    if Utils.get_suffix(filepath) == "list":
        EventBus.list_file_loaded.emit(filepath)


## 将文本更新保存到内存
func update_subtitle_clips(content: String):
    subtitle_clips = Utils.parse_edit_text(content)


func merge_with_next_clip():
    if current_clip_index == num_clips - 1:
        return

    var next_clip = subtitle_clips[current_clip_index + 1]
    current_clip.end = next_clip.end
    current_clip.first_text += next_clip.first_text
    current_clip.second_text += next_clip.second_text
    subtitle_clips.remove_at(current_clip_index + 1)


func get_next_long_sentence_index():
    var i = current_clip_index + 1
    while i < num_clips:
        if subtitle_clips[i].first_text.length() > 42:
            return i
        i += 1
    return -1


func export_subtitle_file(filepath: String = "", only_first=false, save_path=true):
    if save_path:
        subtitle_filepath = filepath

    if not filepath:
        filepath = subtitle_filepath

    if subtitle_clips.size() == 0:
        Logger.warn("No valid clips exists!")
        return

    var export_file = FileAccess.open(filepath, FileAccess.WRITE)

    var content: String = ""
    if Utils.get_suffix(filepath) == "ass":
        content += Utils.ASS_TEMPLATE
        for clip in subtitle_clips:
            if only_first:
                content += Utils.ASS_DIALOG_FORMAT_ONLY_FIRST % [
                    0, # layer
                    Utils.time_float2str(clip.start_time, "ass"),
                    Utils.time_float2str(clip.end_time, "ass"),
                    clip.first_text,
                ]
            else:
                content += Utils.ASS_DIALOG_FORMAT % [
                    0, # layer
                    Utils.time_float2str(clip.start_time, "ass"),
                    Utils.time_float2str(clip.end_time, "ass"),
                    clip.first_text, clip.second_text
                ]
        export_file.store_string(content)
    else:
        export_file.store_string(get_full_text())


func get_full_text() -> String:
    var full_text := ""
    for clip in subtitle_clips:
        full_text += clip.full_edit_text()
    return full_text


func is_empty() -> bool:
    return num_clips == 0


## 随时间更新current_clip_index和高亮区域
func update(play_time: float):
    if is_empty():
        return

    var ret = current_clip.compare_time_with_clip(play_time)
    if ret == 0:
        return
    elif ret == 1:
        if subtitle_clips[clampi(current_clip_index + 1, 0, num_clips)].compare_time_with_clip(play_time) == 0:
            current_clip_index += 1
            return
        current_clip_index = bin_search(play_time, current_clip_index, num_clips)
    else:
        current_clip_index = bin_search(play_time, 0, current_clip_index)


@warning_ignore("integer_division")
func bin_search(play_time: float, left: int, right: int) -> int:
    while left <= right:
        var mid = left + (right - left) / 2  # 防止(left + right)整数溢出的情况
        var ret =  subtitle_clips[mid].compare_time_with_clip(play_time)
        if ret == 0:
            return mid  # 找到目标值，返回其索引
        elif ret == 1:
            left = mid + 1  # 调整搜索区间到右半部分
        else:
            right = mid - 1  # 调整搜索区间到左半部分

    return left
