extends Control

var _peers: Array = []

func _ready() -> void:
	_test("wss://ws.postman-echo.com/raw")
	_test("wss://relay.the-legend-of-beef.todi.wtf/v1/login/ws?session_id=test-diag")
	_test("wss://relay.the-legend-of-beef.todi.wtf/healthz")
	_test("wss://relay.the-legend-of-beef.todi.wtf/")
	_test("wss://todi.wtf/")

func _test(url: String) -> void:
	print("[diag] connecting ", url)
	var ws := WebSocketPeer.new()
	var err := ws.connect_to_url(url)
	if err != OK:
		print("[diag] FAIL connect_to_url for ", url, ": ", err)
		return
	_peers.append({"url": url, "ws": ws, "last": -1, "deadline": Time.get_ticks_msec() + 8000})

func _process(_dt: float) -> void:
	for entry in _peers:
		var ws: WebSocketPeer = entry["ws"]
		ws.poll()
		var s := ws.get_ready_state()
		if s != entry["last"]:
			print("[diag] ", entry["url"], " state ", entry["last"], " -> ", s)
			entry["last"] = s
		if s == WebSocketPeer.STATE_OPEN:
			print("[diag] OPEN: ", entry["url"])
			ws.close()
			entry["last"] = WebSocketPeer.STATE_CLOSED
		elif s == WebSocketPeer.STATE_CLOSED and entry["last"] != -1 and Time.get_ticks_msec() < entry["deadline"]:
			pass
		elif Time.get_ticks_msec() > entry["deadline"] and s != WebSocketPeer.STATE_CLOSED:
			print("[diag] TIMEOUT (still in state ", s, "): ", entry["url"])
			ws.close()
			entry["last"] = WebSocketPeer.STATE_CLOSED
