class_name WhisperWords
extends RefCounted

class Word:
    var word: String
    var start: float
    var end: float
    var is_end: bool

    func _init(w_arr: Array):
        word = w_arr[0].strip_edges()
        start = float(w_arr[1])
        end = float(w_arr[2])
        is_end = false

    func _to_string():
        return "(%s, %s)" % [word, is_end]

var words: Array[Word]
var clips: Array[SubtitleClip]


func _init(json: String):
    var word_list = JSON.parse_string(json)
    assert(typeof(word_list) == TYPE_ARRAY, "Invalid Json Msg: %s" % json)
    for w_arr in word_list:
        words.append(Word.new(w_arr))
    words[-1].is_end = true


func get_full_text() -> String:
    return " ".join(words.map(func (word): return word.word))


func mark_word_as_end(line: int, column: int):
    var l = 0
    var c = 0
    for word in words:
        if word.is_end:
            l += 1

        # 指向尾空格
        c += len(word.word)

        if line == l and column <= c:
            word.is_end = true
            break

        # 跳过尾空格
        c += 1


func construct_clips():
    clips.clear()
    var clip: SubtitleClip = SubtitleClip.new()
    var clip_start = true
    for word in words:
        clip.second_text += " " + word.word
        if clip_start:
            clip.start = Utils.time_float2str(word.start)
            clip_start = false
        if word.is_end:
            clip.end = Utils.time_float2str(word.end)
            clip.second_text = clip.second_text.strip_edges()
            clips.append(clip)
            clip = SubtitleClip.new()
            clip_start = true


func get_clips_text() -> String:
    var full_text := ""
    for clip in clips:
        full_text += clip.full_edit_text()
    return full_text
