class_name SubtitleClip
extends Object

var id: int = -1
var start: String
var end: String
## ms
var start_time: float:
    get: return Utils.time_str2float(start)
## ms
var end_time: float:
    get: return Utils.time_str2float(end)
var first_text: String
var second_text: String
#var style

## 0: 时间在clip内。 1: 时间在clip后。 2: 时间在clip前。
func compare_time_with_clip(time: float) -> int:
    if time > end_time:
        return 1
    elif time < start_time:
        return -1
    else:
        return 0


func full_edit_text() -> String:
    return "[%s->%s]\n%s\n%s\n\n" % [start, end, first_text, second_text]


func ass_dialog_line() -> String:
    return "Dialogue: 0,%s,%s,ZH,,0,0,0,,%s\\N{\\rEN}%s\n" % [start, end, first_text, second_text]


func get_clip_time_range() -> String:
    # 稍长一点防止识别不完整。
    return str(start_time) + "," + str(end_time + 0.3)


func _to_string() -> String:
    return "[%s->%s]%s|%s" % [start, end, first_text, second_text]
