@tool
extends Node

enum LogLevel { DEBUG, INFO, WARN, ERROR, FATAL }

const FRAME_TABLE_BBCODE = "[b]Frame Stack[/b]\n[table=3]
                            [cell border=#fff3] Frame [/cell]
                            [cell border=#fff3] Source [/cell]
                            [cell border=#fff3] Function [/cell]
                            %s[/table]"
const FRAME_TABLE_CELLS = "[cell border=#fff3] %d [/cell]
                            [cell border=#fff3] %s [/cell]
                            [cell border=#fff3] %s [/cell]"
const LOG_LEVEL_TO_COLOR: Dictionary = {
    0: "white",
    1: "green",
    2: "yellow",
    3: "crimson",
    4: "red",
}
const log_file_format = "[{time}] {level} {message} {loc_info}"

var message_line_length: int = 145
var global_log_level: LogLevel = LogLevel.DEBUG
var location_with_method_name: bool = true
var array_cells_in_one_line: int = 5
var write_logs: bool = false
var log_dir: String = "res://log"
var log_filename: String = "game.log"
var _file


func set_loglevel(level: LogLevel):
    global_log_level = level


func generic_log(message, log_level=LogLevel.INFO, node_name=""):
    if global_log_level > log_level:
        return

    var loc_info = ""
    var stack_array := []
    if not Engine.is_editor_hint():
        stack_array = get_stack()
        var desired_stack_index = 2 if stack_array.size() >= 3 else 0

        if node_name != "":
            node_name += ":"
        var func_name = ""
        if location_with_method_name:
            func_name = stack_array[desired_stack_index]["function"] + ":"
        loc_info = "%s%s:%s%d" % [
            node_name,
            stack_array[desired_stack_index]["source"].split("/")[-1],
            func_name,
            stack_array[desired_stack_index]["line"]]

    var color_str = LOG_LEVEL_TO_COLOR[log_level]
    var now = Time.get_datetime_dict_from_system(false)

    var log_msg_format = "[color=orange][{time}][/color] [color=%s]{level}[/color] [color=orange] {loc_info}[/color]\n {message}" % color_str
    var msg = ""
    var message_string = ""
    if typeof(message) == TYPE_DICTIONARY:
        message_string = "                 [table=2]
                        [cell border=LIME_GREEN] [b]Key[/b] [/cell]
                        [cell border=LIME_GREEN] [b]Value[/b] [/cell]"
        for k in message.keys():
            message_string += "[cell border=LIME_GREEN] %s [/cell]
                               [cell border=LIME_GREEN] %s [/cell]" % [k, message[k]]
        message_string += "[/table]"
    elif typeof(message) == TYPE_ARRAY:
        var table_cells = array_cells_in_one_line if message.size() > array_cells_in_one_line \
                            else message.size()
        message_string = "                 [table=%d]" % table_cells
        for el in message:
            message_string += "[cell border=LIME_GREEN] %s [/cell]" % el
        if message.size() % array_cells_in_one_line != 0 and message.size() > array_cells_in_one_line:
            for i in array_cells_in_one_line - message.size() % array_cells_in_one_line:
                message_string += "[cell border=LIME_GREEN]   [/cell]"
        message_string += "[/table]"
    else:
        log_msg_format = "[table=3]
            [cell][color=orange][{time}][/color] [color=%s]{level}[/color] [/cell]
            [cell][color=%s]{message}[/color][/cell]
            [cell][color=orange] {loc_info}[/color][/cell]
        [/table]" % [color_str, color_str]
        message_string = "%-*s" % [message_line_length - loc_info.length() - 19, message]

    msg = log_msg_format.format(
        {
            "loc_info": "%s" % loc_info,
            "message": message_string,
            "time": "{0}:{1}:{2}".format({
                                0: "%02d" % now["hour"],
                                1: "%02d" % now["minute"],
                                2: "%02d" % now["second"],
                            }),
            "level": "%-5s" % LogLevel.keys()[log_level],
        })

    match log_level:
        LogLevel.DEBUG:
            print_rich(msg)
        LogLevel.INFO:
            print_rich(msg)
        LogLevel.WARN:
            print_rich(msg)
        LogLevel.ERROR:
            print_rich(msg)
            _print_valid_frames(stack_array)
        LogLevel.FATAL:
            print_rich(msg)
            _print_valid_frames(stack_array)
            if is_inside_tree():
                get_tree().quit()
        _:
            print(msg)

    if write_logs:
        _write_logs(log_file_format.format({
                        "loc_info": "%s" % loc_info,
                        "message": message,
                        "time": "{0}:{1}:{2}".format({
                                        0: "%02d" % now["hour"],
                                        1: "%02d" % now["minute"],
                                        2: "%02d" % now["second"],
                                    }),
                        "level": "%-5s" % LogLevel.keys()[log_level],
                    }))

func debug(message, node_name=""):
    call_thread_safe("generic_log",message,LogLevel.DEBUG, node_name)


func info(message, node_name=""):
    call_thread_safe("generic_log",message, LogLevel.INFO, node_name)


func warn(message, node_name=""):
    call_thread_safe("generic_log",message,LogLevel.WARN, node_name)


func error(message, node_name=""):
    call_thread_safe("generic_log",message,LogLevel.ERROR, node_name)


func fatal(message, node_name=""):
    call_thread_safe("generic_log",message,LogLevel.FATAL, node_name)


func _print_valid_frames(stack_array: Array):
    if not Engine.is_editor_hint():
        var desired_stack_index = 2 if stack_array.size() >= 3 else 0
        var table_cell_bbcode = ""
        for i in range(desired_stack_index, stack_array.size()):
            table_cell_bbcode += FRAME_TABLE_CELLS % [i - desired_stack_index, stack_array[i].source + ":" + str(stack_array[i].line), stack_array[i].function]
        print_rich(FRAME_TABLE_BBCODE % table_cell_bbcode)


func _write_logs(message):
    if _file == null:
        DirAccess.make_dir_recursive_absolute(log_dir)
        _file = FileAccess.open(log_dir + "/" + log_filename, FileAccess.WRITE)
    _file.store_line("%s" % message)
