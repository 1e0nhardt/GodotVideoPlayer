extends Node

signal asr_completed(words: WhisperWords)
signal qwen_translate_completed(result: Array)
signal qwen_call_once_completed(result: String)

const WS_URL = "ws://localhost:5000"

var socket := WebSocketPeer.new()
var socket_closed: bool = true
var _id := 0


func _ready():
    # 设置消息大小限制
    socket.inbound_buffer_size = 5*1024*1024
    socket.outbound_buffer_size = 5*1024*1024
    connect_to_python()


func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        socket.close()
        Logger.info("Socket closed")


func _process(_delta):
    socket.poll()
    match socket.get_ready_state():
        WebSocketPeer.STATE_OPEN:
            while socket.get_available_packet_count():
                var pkt = socket.get_packet()
                if socket.was_string_packet():
                    #Logger.debug("Packet String: %s" % pkt.get_string_from_utf8())
                    pass
                else:
                    Logger.debug("Packet Data: %s" % pkt)
                    continue
                var msg_json = JSON.parse_string(pkt.get_string_from_utf8())
                #TODO 根据接受的消息类型发送相应的信号
                #var msg_content = "Packet: %s" % msg_json["msg"]
                #Logger.debug(msg_content)
                if msg_json["task_progress"] == 100:
                    Logger.info("Task %s: %s Compeletd!" % [msg_json["task_id"], msg_json["task_progress"]])
                    if msg_json["type"] == "asr":
                        asr_completed.emit(WhisperWords.new(msg_json["data"]))
                    elif msg_json["type"] == "qwen_translate":
                        qwen_translate_completed.emit(msg_json["data"])
                    elif msg_json["type"] == "qwen_call_once":
                        qwen_call_once_completed.emit(msg_json["data"])
                else:
                    Logger.info("Task %s: %s" % [msg_json["task_id"], msg_json["task_progress"]])

        WebSocketPeer.STATE_CLOSING:
            # Keep polling to achieve proper close.
            Logger.warn("Websocket State Closing.")
        WebSocketPeer.STATE_CLOSED:
            var code = socket.get_close_code()
            var reason = socket.get_close_reason()
            Logger.warn("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
            set_process(false) # Stop processing.
            socket_closed = true


func connect_to_python():
    if not socket_closed:
        return

    var state = socket.connect_to_url(WS_URL)
    if state == OK:
        socket_closed = false
    Logger.info("Connet to %s %s" % [WS_URL, state])


func send(msg_dict: Dictionary) -> int:
    msg_dict["task_id"] = gen_id()
    var state := socket.send_text(JSON.stringify(msg_dict))
    Logger.debug("Send Task (type=%s, task_id=%s)" % [msg_dict["type"], msg_dict["task_id"]])
    if state: # 服务器端重启后，第一次send会失败。
        Logger.debug("Retry once")
        #while socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
            #socket.poll()
        if socket_closed:
            connect_to_python()
            set_process(true)
        await get_tree().create_timer(0.1).timeout
        socket.send_text(JSON.stringify(msg_dict))
    return state


func gen_id() -> int:
    _id += 1
    return _id;
