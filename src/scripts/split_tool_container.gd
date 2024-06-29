extends HSplitContainer

var default_background_color: Color
var reg = RegEx.create_from_string(r"\[(.*->.*)\](.*)")

@onready var translated_text_edit: CodeEdit = %TranslatedTextEdit


func _ready() -> void:
    default_background_color = translated_text_edit.get_line_background_color(0)


func is_line_time_text_match(raw_lines, translated_lines, lineno: int):
    var reg_match: RegExMatch
    var raw_time_text
    var translated_time_text

    reg_match = reg.search(raw_lines[lineno])
    if reg_match:
        raw_time_text = reg_match.get_string(1)
    else:
        Logger.warn("Invalid line! => %s" % raw_lines[lineno])

    if lineno > translated_lines.size() - 1:
        return false

    reg_match = reg.search(translated_lines[lineno])
    if reg_match:
        translated_time_text = reg_match.get_string(1)
    else:
        Logger.warn("Invalid line! => %s" % translated_lines[lineno])

    return raw_time_text == translated_time_text

func _on_translated_text_edit_text_changed() -> void:
    var raw_content = %RawTextEdit.text
    var translated_content = translated_text_edit.text

    var raw_lines = raw_content.strip_edges().split("\n")
    var translated_lines = translated_content.strip_edges().split("\n")

    # 修复有时第一行一直高亮的问题。
    for i in translated_lines.size():
        translated_text_edit.set_line_background_color(
            i, default_background_color
        )

    for i in raw_lines.size():
        if not is_line_time_text_match(raw_lines, translated_lines, i):
            if i < translated_lines.size():
                translated_text_edit.set_line_background_color(i, Color.DARK_OLIVE_GREEN)
                translated_text_edit.set_line_as_center_visible(i)
            break

