extends Node

const RELAY := "https://relay.the-legend-of-beef.todi.wtf"
const CLIENT_ID := RELAY + "/client-metadata.json"
const REDIRECT_URI := RELAY + "/v1/login/callback"
const SCOPE := "atproto repo:actor.rpg.stats repo:actor.rpg.sprite repo:actor.rpg.master blob:image/*"
const WS_TIMEOUT_SEC := 300.0

signal login_started(slot: int, authorize_url: String)
signal login_completed(slot: int, did: String, handle: String)
signal login_failed(slot: int, error: String)

# Per-slot state dict keys:
#   dpop_key: Dictionary (from DpopUtil.generate_keypair)
#   dpop_nonce: String
#   code_verifier: String
#   session_id: String
#   access_token: String
#   refresh_token: String
#   did: String
#   handle: String
#   pds: String
#   auth_server_meta: Dictionary
#   ws: WebSocketPeer
#   ws_start_time: float
#   ws_code_result: Dictionary  (set when WS delivers auth_code)
#   cancelled: bool
#   sprite_png: PackedByteArray  (cached after login; empty if none)
#   stat_budget: StatBudget      (set by player_select_screen after _parse_stats)
var _slots: Dictionary = {}

var _crypto := Crypto.new()


func _process(delta: float) -> void:
	for slot in _slots.keys():
		_poll_ws(slot)


func start_login(slot: int, handle: String) -> void:
	cancel_login(slot)
	_slots[slot] = {
		"dpop_key": {},
		"dpop_nonce": "",
		"code_verifier": "",
		"session_id": "",
		"access_token": "",
		"refresh_token": "",
		"did": "",
		"handle": handle.lstrip("@"),
		"pds": "",
		"auth_server_meta": {},
		"ws": null,
		"ws_start_time": 0.0,
		"ws_code_result": {},
		"cancelled": false,
		"sprite_png": PackedByteArray(),
		"stat_budget": null,
	}
	_run_login_flow(slot)


func cancel_login(slot: int) -> void:
	if not _slots.has(slot):
		return
	var st: Dictionary = _slots[slot]
	st["cancelled"] = true
	_close_ws(slot)
	_slots.erase(slot)


func is_authenticated(slot: int) -> bool:
	return _slots.has(slot) and not (_slots[slot]["access_token"] as String).is_empty()


func get_did(slot: int) -> String:
	if not _slots.has(slot):
		return ""
	return _slots[slot]["did"]


func get_handle(slot: int) -> String:
	if not _slots.has(slot):
		return ""
	return _slots[slot]["handle"]


func get_access_token(slot: int) -> String:
	if not _slots.has(slot):
		return ""
	return _slots[slot]["access_token"]


func get_pds(slot: int) -> String:
	if not _slots.has(slot):
		return ""
	return _slots[slot]["pds"]


func get_dpop_key(slot: int) -> Dictionary:
	if not _slots.has(slot):
		return {}
	return _slots[slot].get("dpop_key", {})


# Returns a one-key dict {"value": <current_nonce>} wrapping the live slot nonce.
# AtprotoHelpers mutates ["value"] on nonce retry; caller must flush back via
# flush_dpop_nonce_holder() after the call.
func get_dpop_nonce_holder(slot: int) -> Dictionary:
	if not _slots.has(slot):
		return {"value": ""}
	return {"value": _slots[slot].get("dpop_nonce", "")}


func flush_dpop_nonce_holder(slot: int, holder: Dictionary) -> void:
	if not _slots.has(slot):
		return
	_slots[slot]["dpop_nonce"] = holder.get("value", "")


func logout(slot: int) -> void:
	cancel_login(slot)


func get_sprite_png(slot: int) -> PackedByteArray:
	if not _slots.has(slot):
		return PackedByteArray()
	return _slots[slot].get("sprite_png", PackedByteArray())


func get_stat_budget(slot: int) -> StatBudget:
	if not _slots.has(slot):
		return null
	return _slots[slot].get("stat_budget", null)


func set_stat_budget(slot: int, budget: StatBudget) -> void:
	if not _slots.has(slot):
		return
	_slots[slot]["stat_budget"] = budget


# Returns true on success, false on any failure. Caller handles retry / cancel.
func save_stats(slot: int, budget: StatBudget) -> bool:
	if not _slots.has(slot):
		return false
	var st: Dictionary = _slots[slot]
	var access_token: String = st.get("access_token", "")
	if access_token.is_empty():
		return false
	var dpop_key: Dictionary = st.get("dpop_key", {})
	if dpop_key.is_empty():
		return false
	var pds: String = st.get("pds", "")
	var did: String = st.get("did", "")
	if pds.is_empty() or did.is_empty():
		return false
	var data := {
		"vit": budget.vit,
		"str_stat": budget.str_stat,
		"agi": budget.agi,
		"tgh": budget.tgh,
	}
	var nonce_holder := {"value": st.get("dpop_nonce", "")}
	var result := await AtprotoHelpers.merge_and_put_stats(
		self, pds, did, "the_legend_of_beef", data, access_token, dpop_key, nonce_holder
	)
	st["dpop_nonce"] = nonce_holder.get("value", "")
	return not result.is_empty()


# ── internal flow ────────────────────────────────────────────────────────────

func _run_login_flow(slot: int) -> void:
	var st: Dictionary = _slots[slot]

	# 1. PKCE
	var verifier_bytes := _crypto.generate_random_bytes(64)
	st["code_verifier"] = _b64u(verifier_bytes)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((st["code_verifier"] as String).to_utf8_buffer())
	var challenge := _b64u(ctx.finish())

	# 2. DPoP keypair (per-slot, never shared)
	st["dpop_key"] = DpopUtil.generate_keypair()

	# 3. Resolve handle -> DID + PDS
	var identity := await AtprotoHelpers.resolve_handle(self, st["handle"])
	if _guard(slot): return
	if identity.is_empty() or (identity.get("did", "") as String).is_empty():
		_fail(slot, "resolve_handle_failed: " + st["handle"])
		return
	st["did"] = identity["did"]
	st["pds"] = identity["pds"]

	# 4. Auth server discovery
	var meta := await AtprotoHelpers.fetch_auth_metadata(self, st["pds"])
	if _guard(slot): return
	if meta.is_empty() or not meta.has("pushed_authorization_request_endpoint"):
		_fail(slot, "auth_metadata_missing_par_endpoint")
		return
	st["auth_server_meta"] = meta

	# 5. Open relay session
	var start_resp := await _http_raw(RELAY + "/v1/login/start", HTTPClient.METHOD_POST, [], PackedByteArray())
	if _guard(slot): return
	var start_code: int = start_resp["code"]
	if start_code < 200 or start_code >= 300:
		_fail(slot, "relay_start_failed: http " + str(start_code))
		return
	var start_json = JSON.parse_string(start_resp["body"])
	if start_json == null or not start_json.has("session_id"):
		_fail(slot, "relay_start_bad_json")
		return
	st["session_id"] = start_json["session_id"]

	# 6. Open WebSocket BEFORE building the authorize URL so it's ready when callback arrives
	var ws_url: String = RELAY.replace("https://", "wss://") + "/v1/login/ws?session_id=" + st["session_id"]
	var ws := WebSocketPeer.new()
	var ws_err := ws.connect_to_url(ws_url)
	if ws_err != OK:
		_fail(slot, "ws_connect_failed: " + str(ws_err))
		return
	st["ws"] = ws
	st["ws_start_time"] = Time.get_ticks_msec() / 1000.0

	# Wait for WS to open (poll until OPEN or error, max 10s)
	var ws_open_deadline := Time.get_ticks_msec() + 10000
	while true:
		if _guard(slot): return
		ws.poll()
		var ws_state := ws.get_ready_state()
		if ws_state == WebSocketPeer.STATE_OPEN:
			break
		if ws_state == WebSocketPeer.STATE_CLOSED or ws_state == WebSocketPeer.STATE_CLOSING:
			_fail(slot, "ws_open_failed code=" + str(ws.get_close_code()))
			return
		if Time.get_ticks_msec() > ws_open_deadline:
			_fail(slot, "ws_open_timeout")
			return
		await get_tree().process_frame

	# 7. PAR — Bluesky always returns 400+DPoP-Nonce on first attempt; retry is mandatory
	var par_url: String = st["auth_server_meta"]["pushed_authorization_request_endpoint"]
	var par_body_params := {
		"response_type": "code",
		"client_id": CLIENT_ID,
		"redirect_uri": REDIRECT_URI,
		"code_challenge": challenge,
		"code_challenge_method": "S256",
		"state": st["session_id"],
		"scope": SCOPE,
	}
	var par_body := _urlencoded(par_body_params).to_utf8_buffer()

	var dpop1 := DpopUtil.create_proof(st["dpop_key"], "POST", par_url, st["dpop_nonce"])
	var par_headers1: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"DPoP: " + dpop1,
	]
	var par_resp1 := await _http_raw(par_url, HTTPClient.METHOD_POST, par_headers1, par_body)
	if _guard(slot): return

	var request_uri := ""
	if par_resp1["code"] == 201 or par_resp1["code"] == 200:
		var pj = JSON.parse_string(par_resp1["body"])
		if pj != null and pj.has("request_uri"):
			request_uri = pj["request_uri"]
	else:
		# Bluesky returns 400 with DPoP-Nonce on first attempt — this is the expected retry path
		var nonce := _extract_dpop_nonce(par_resp1["headers"])
		if nonce.is_empty() or par_resp1["code"] != 400:
			_fail(slot, "par_failed: http " + str(par_resp1["code"]) + " " + par_resp1["body"])
			return
		st["dpop_nonce"] = nonce
		var dpop2 := DpopUtil.create_proof(st["dpop_key"], "POST", par_url, nonce)
		var par_headers2: PackedStringArray = [
			"Content-Type: application/x-www-form-urlencoded",
			"DPoP: " + dpop2,
		]
		var par_resp2 := await _http_raw(par_url, HTTPClient.METHOD_POST, par_headers2, par_body)
		if _guard(slot): return
		if par_resp2["code"] != 201 and par_resp2["code"] != 200:
			_fail(slot, "par_retry_failed: http " + str(par_resp2["code"]) + " " + par_resp2["body"])
			return
		# Update nonce if server rotated it again
		var new_nonce := _extract_dpop_nonce(par_resp2["headers"])
		if not new_nonce.is_empty():
			st["dpop_nonce"] = new_nonce
		var pj2 = JSON.parse_string(par_resp2["body"])
		if pj2 == null or not pj2.has("request_uri"):
			_fail(slot, "par_retry_bad_json: " + par_resp2["body"])
			return
		request_uri = pj2["request_uri"]

	if request_uri.is_empty():
		_fail(slot, "par_no_request_uri")
		return

	# 8. Emit authorize URL — user clicks it, logs in on their device
	var auth_ep: String = st["auth_server_meta"]["authorization_endpoint"]
	var authorize_url := auth_ep + "?client_id=" + CLIENT_ID.uri_encode() + "&request_uri=" + request_uri.uri_encode()
	login_started.emit(slot, authorize_url)

	# 9. Wait on WebSocket for {type:"auth_code", code, state, iss}
	var code := await _wait_for_ws_code(slot)
	if _guard(slot): return
	if code.is_empty():
		_fail(slot, "ws_timeout_or_cancelled")
		return
	if code.get("state", "") != st["session_id"]:
		_fail(slot, "state_mismatch")
		return

	# 10. Token exchange — same DPoP-Nonce retry pattern applies
	var token_url: String = st["auth_server_meta"]["token_endpoint"]
	var token_body_params := {
		"grant_type": "authorization_code",
		"code": code["code"],
		"redirect_uri": REDIRECT_URI,
		"code_verifier": st["code_verifier"],
		"client_id": CLIENT_ID,
	}
	var token_body := _urlencoded(token_body_params).to_utf8_buffer()

	var tdpop1 := DpopUtil.create_proof(st["dpop_key"], "POST", token_url, st["dpop_nonce"])
	var tok_headers1: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"DPoP: " + tdpop1,
	]
	var tok_resp1 := await _http_raw(token_url, HTTPClient.METHOD_POST, tok_headers1, token_body)
	if _guard(slot): return

	var tok_json: Variant
	if tok_resp1["code"] == 200:
		tok_json = JSON.parse_string(tok_resp1["body"])
	else:
		# Token endpoint also issues DPoP-Nonce on first attempt
		var tnonce := _extract_dpop_nonce(tok_resp1["headers"])
		if tnonce.is_empty() or tok_resp1["code"] != 400:
			_fail(slot, "token_exchange_failed: http " + str(tok_resp1["code"]) + " " + tok_resp1["body"])
			return
		st["dpop_nonce"] = tnonce
		var tdpop2 := DpopUtil.create_proof(st["dpop_key"], "POST", token_url, tnonce)
		var tok_headers2: PackedStringArray = [
			"Content-Type: application/x-www-form-urlencoded",
			"DPoP: " + tdpop2,
		]
		var tok_resp2 := await _http_raw(token_url, HTTPClient.METHOD_POST, tok_headers2, token_body)
		if _guard(slot): return
		if tok_resp2["code"] != 200:
			_fail(slot, "token_retry_failed: http " + str(tok_resp2["code"]) + " " + tok_resp2["body"])
			return
		var tnonce2 := _extract_dpop_nonce(tok_resp2["headers"])
		if not tnonce2.is_empty():
			st["dpop_nonce"] = tnonce2
		tok_json = JSON.parse_string(tok_resp2["body"])

	if tok_json == null or not tok_json.has("access_token"):
		_fail(slot, "token_bad_json: " + str(tok_json))
		return

	# 11. Store tokens; sub is the DID
	st["access_token"] = tok_json["access_token"]
	st["refresh_token"] = tok_json.get("refresh_token", "")
	if tok_json.has("sub"):
		st["did"] = tok_json["sub"]

	_close_ws(slot)

	# 11b. Re-resolve PDS from the actual logged-in DID. The pds we resolved earlier was
	# tied to the handle we used for resolution (e.g. "bsky.app" → puffball). The real
	# user may live on a different PDS host (jellybaby, morel, etc.); the access token's
	# `aud` claim is bound to that host, so authenticated writes must go to it.
	var real_pds := await AtprotoHelpers.pds_from_did(self, st["did"])
	if not _guard(slot) and not real_pds.is_empty():
		st["pds"] = real_pds

	# 12. Resolve real handle from the DID via public AppView (unauthenticated)
	var profile_url := "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=" + (st["did"] as String).uri_encode()
	var profile_resp := await _http_raw(profile_url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if not _guard(slot) and profile_resp["code"] == 200:
		var profile_json = JSON.parse_string(profile_resp["body"])
		if profile_json is Dictionary and not (profile_json.get("handle", "") as String).is_empty():
			st["handle"] = profile_json["handle"]

	# 13. Fetch rpg.actor sprite (unauthenticated read — never blocks login on failure)
	var sprite_bytes := await AtprotoHelpers.get_sprite(self, st["did"])
	if not _guard(slot):
		st["sprite_png"] = sprite_bytes if sprite_bytes != null else PackedByteArray()

	# 14. Done
	login_completed.emit(slot, st["did"], st["handle"])


# ── WebSocket polling (called from _process) ─────────────────────────────────

func _poll_ws(slot: int) -> void:
	if not _slots.has(slot):
		return
	var st: Dictionary = _slots[slot]
	var ws: WebSocketPeer = st["ws"]
	if ws == null:
		return
	ws.poll()
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		var msg = JSON.parse_string(pkt.get_string_from_utf8())
		if msg is Dictionary and msg.get("type") == "auth_code":
			st["ws_code_result"] = msg


func _wait_for_ws_code(slot: int) -> Dictionary:
	var st: Dictionary = _slots[slot]
	var deadline := Time.get_ticks_msec() / 1000.0 + WS_TIMEOUT_SEC
	while true:
		if _guard(slot): return {}
		# Drain inline so we never miss a packet queued just before the WS closes —
		# the relay sends auth_code and closes immediately (single-use code), and
		# _process polling can race with that sequence.
		var ws: WebSocketPeer = st["ws"]
		if ws != null:
			ws.poll()
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet()
				var msg = JSON.parse_string(pkt.get_string_from_utf8())
				if msg is Dictionary and msg.get("type") == "auth_code":
					st["ws_code_result"] = msg
		if not (st["ws_code_result"] as Dictionary).is_empty():
			return st["ws_code_result"]
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			return {}
		if Time.get_ticks_msec() / 1000.0 >= deadline:
			return {}
		await get_tree().process_frame
	return {}


func _close_ws(slot: int) -> void:
	if not _slots.has(slot):
		return
	var ws: WebSocketPeer = _slots[slot]["ws"]
	if ws != null:
		ws.close()
		_slots[slot]["ws"] = null


# ── HTTP helper — exposes raw status codes and headers for DPoP-Nonce retry ──

func _http_raw(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	var req := HTTPRequest.new()
	req.body_size_limit = 4 * 1024 * 1024
	add_child(req)
	await get_tree().process_frame
	req.request_raw(url, headers, method, body)
	var result: Array = await req.request_completed
	req.queue_free()

	var resp_code: int = result[1]
	var resp_headers: PackedStringArray = result[2]
	var resp_body: PackedByteArray = result[3]
	return {
		"code": resp_code,
		"headers": resp_headers,
		"body": resp_body.get_string_from_utf8(),
	}


# ── helpers ───────────────────────────────────────────────────────────────────

func _guard(slot: int) -> bool:
	return not _slots.has(slot) or (_slots[slot]["cancelled"] as bool)


func _fail(slot: int, error: String) -> void:
	_close_ws(slot)
	_slots.erase(slot)
	login_failed.emit(slot, error)


func _urlencoded(params: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in params:
		parts.append(str(k).uri_encode() + "=" + str(params[k]).uri_encode())
	return "&".join(parts)


func _extract_dpop_nonce(headers: PackedStringArray) -> String:
	for h: String in headers:
		if h.to_lower().begins_with("dpop-nonce:"):
			return h.split(":", true, 1)[1].strip_edges()
	return ""


func _b64u(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").rstrip("=")
