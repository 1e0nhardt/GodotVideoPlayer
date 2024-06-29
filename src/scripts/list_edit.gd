extends CodeEdit

var list_lines: PackedStringArray
var page_size: int = 50
var total_pages: int:
    get:
        if list_lines.size() % page_size == 0:
            @warning_ignore("integer_division")
            return list_lines.size() / page_size
        else:
            @warning_ignore("integer_division")
            return list_lines.size() / page_size + 1
var curr_page_num: int = 0
var curr_page_text: String:
    get:
        return "\n".join(list_lines.slice(curr_page_num * page_size, (curr_page_num + 1) * page_size))

@onready var page_numer: Label = %PageNumer


func _ready() -> void:
    EventBus.list_file_loaded.connect(func(filepath):
        var file_content = FileAccess.get_file_as_string(filepath).strip_edges()
        file_content = file_content.replace("\r\n", "\n")
        list_lines = file_content.split("\n")
        update_edit_content()
    )


func update_edit_content():
    text = curr_page_text
    page_numer.text = "%d/%d" % [curr_page_num + 1, total_pages]


func _on_prev_page_pressed() -> void:
    curr_page_num = clampi(curr_page_num - 1, 0, total_pages)
    update_edit_content()


func _on_next_page_pressed() -> void:
    curr_page_num = clampi(curr_page_num + 1, 0, total_pages - 1)
    update_edit_content()


func _on_copy_page_pressed() -> void:
    select_all()
    copy()
    deselect()
