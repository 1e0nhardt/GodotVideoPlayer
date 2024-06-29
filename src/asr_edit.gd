class_name AsrEdit
extends TextEdit

var asr_words: WhisperWords
# 重新ASR的片段的原中文部分。
var raw_clip_first_text: String


func _ready():
    WS.asr_completed.connect(on_asr_completed)
    WS.qwen_translate_completed.connect(on_qwen_translate_completed)

    # 右键菜单
    var menu = get_menu()
    menu.item_count = 0
    menu.add_item("分割", MENU_MAX + 1)
    menu.id_pressed.connect(func(id):
        match id:
            MENU_MAX + 1:
                var caret_line_num = get_caret_line()
                var caret_column_num = get_caret_column()
                var line = get_line(caret_line_num)
                var split_pos = line.find(" ", caret_column_num)
                if split_pos != -1:
                    set_caret_column(split_pos)
                    for i in range(caret_line_num):
                        split_pos += len(get_line(i)) - 1
                    asr_words.mark_word_as_end(caret_line_num, split_pos)
                    insert_text_at_caret("\n")
                else:
                    Logger.debug("后面没有空格了！")
    )


func on_asr_completed(words: WhisperWords):
    asr_words = words
    text = asr_words.get_full_text()


func on_qwen_translate_completed(result: Array):
    for i in result.size():
        asr_words.clips[i].first_text = result[i].strip_edges()
    text = asr_words.get_clips_text()


#TODO 添加一个Google翻译按钮
func _on_translate_btton_pressed():
    asr_words.construct_clips()
    var raw_content: String = ""
    for clip in asr_words.clips:
        raw_content += "[%.2f->%.2f]%s\n" % [clip.start_time, clip.end_time, clip.second_text]

    WS.send({
        "type": "qwen_translate",
        "payload": raw_content
    })


func _on_split_button_pressed() -> void:
    asr_words.construct_clips()
    asr_words.clips[0].first_text = raw_clip_first_text
    text = asr_words.get_clips_text()
    $"../HBoxContainer/ConfirmBtton".pressed.emit()
