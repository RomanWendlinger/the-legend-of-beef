class_name AtprotoHelpers


# Returns {code, headers: PackedStringArray, body_str, body_bytes}.
static func _http_raw(
	parent: Node,
	url: String,
	method: HTTPClient.Method,
	headers: PackedStringArray,
	body: PackedByteArray,
) -> Dictionary:
	var req := HTTPRequest.new()
	req.body_size_limit = 4 * 1024 * 1024
	parent.add_child(req)
	await parent.get_tree().process_frame
	req.request_raw(url, headers, method, body)
	var result: Array = await req.request_completed
	req.queue_free()
	return {
		"code": result[1] as int,
		"headers": result[2] as PackedStringArray,
		"body_str": (result[3] as PackedByteArray).get_string_from_utf8(),
		"body_bytes": result[3] as PackedByteArray,
	}


# {did, pds}; empty Dict on failure. handle may have a leading "@".
static func resolve_handle(parent: Node, handle: String) -> Dictionary:
	var clean := handle.lstrip("@")
	var resolve_url := "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=" + clean.uri_encode()
	var r := await _http_raw(parent, resolve_url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if r["code"] < 200 or r["code"] >= 300:
		return {}
	var parsed = JSON.parse_string(r["body_str"])
	if not parsed is Dictionary:
		return {}
	var did: String = parsed.get("did", "")
	if did.is_empty():
		return {}
	var pds := await _pds_from_did(parent, did)
	if pds.is_empty():
		return {}
	return { "did": did, "pds": pds }


# Auth server endpoints dict. Empty Dict on failure.
static func fetch_auth_metadata(parent: Node, pds: String) -> Dictionary:
	var resource_url := pds.trim_suffix("/") + "/.well-known/oauth-protected-resource"
	var r1 := await _http_raw(parent, resource_url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if r1["code"] < 200 or r1["code"] >= 300:
		return {}
	var resource = JSON.parse_string(r1["body_str"])
	if not resource is Dictionary:
		return {}
	var auth_servers = resource.get("authorization_servers", [])
	if not auth_servers is Array or (auth_servers as Array).size() == 0:
		return {}
	var auth_server_url: String = auth_servers[0]

	var meta_url := auth_server_url.trim_suffix("/") + "/.well-known/oauth-authorization-server"
	var r2 := await _http_raw(parent, meta_url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if r2["code"] < 200 or r2["code"] >= 300:
		return {}
	var meta = JSON.parse_string(r2["body_str"])
	if not meta is Dictionary:
		return {}
	return meta


# Raw PNG bytes from rpg.actor. Empty PackedByteArray on non-2xx or failure.
static func get_sprite(parent: Node, did: String) -> PackedByteArray:
	var url := "https://rpg.actor/api/sprite/normalized?did=" + did.uri_encode()
	var r := await _http_raw(parent, url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if r["code"] < 200 or r["code"] >= 300:
		return PackedByteArray()
	return r["body_bytes"]


# {value: {...}, ...} record body. Empty Dict if 404 or error.
static func get_record(
	parent: Node,
	pds: String,
	did: String,
	collection: String,
	rkey: String = "self",
) -> Dictionary:
	var url := (pds.trim_suffix("/")
		+ "/xrpc/com.atproto.repo.getRecord"
		+ "?repo=" + did.uri_encode()
		+ "&collection=" + collection.uri_encode()
		+ "&rkey=" + rkey.uri_encode())
	var r := await _http_raw(parent, url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if r["code"] < 200 or r["code"] >= 300:
		return {}
	var parsed = JSON.parse_string(r["body_str"])
	if not parsed is Dictionary:
		return {}
	return parsed


# Authenticated PUT with DPoP-Nonce retry. nonce_holder is {"value": ""} passed by caller.
static func put_record(
	parent: Node,
	pds: String,
	did: String,
	collection: String,
	rkey: String,
	record_value: Dictionary,
	access_token: String,
	dpop_key: Dictionary,
	nonce_holder: Dictionary,
) -> Dictionary:
	var url := pds.trim_suffix("/") + "/xrpc/com.atproto.repo.putRecord"
	var body_dict := { "repo": did, "collection": collection, "rkey": rkey, "record": record_value }
	var body := JSON.stringify(body_dict).to_utf8_buffer()

	print("[put_record] starting; nonce_in='", nonce_holder["value"], "' body=", body.get_string_from_utf8().substr(0, 300))
	var resp := await _put_attempt(parent, url, body, access_token, dpop_key, nonce_holder["value"])
	print("[put_record] attempt 1 code=", resp["code"], " body=", resp["body_str"].substr(0, 400))
	# Auth servers reject with 400+use_dpop_nonce; resource servers reject with 401+use_dpop_nonce.
	# Retry whenever the response carries a fresh DPoP-Nonce header.
	if resp["code"] == 400 or resp["code"] == 401:
		var new_nonce := _extract_dpop_nonce(resp["headers"])
		print("[put_record] extracted nonce='", new_nonce, "'")
		if not new_nonce.is_empty():
			nonce_holder["value"] = new_nonce
			resp = await _put_attempt(parent, url, body, access_token, dpop_key, new_nonce)
			print("[put_record] attempt 2 code=", resp["code"], " body=", resp["body_str"].substr(0, 400))

	if resp["code"] < 200 or resp["code"] >= 300:
		return {}
	var parsed = JSON.parse_string(resp["body_str"])
	if not parsed is Dictionary:
		return {}
	return parsed


# Read actor.rpg.stats, merge data under system_key, write back.
# Preserves other systems' data. Returns server response Dict.
static func merge_and_put_stats(
	parent: Node,
	pds: String,
	did: String,
	system_key: String,
	data: Dictionary,
	access_token: String,
	dpop_key: Dictionary,
	nonce_holder: Dictionary,
) -> Dictionary:
	print("[merge_and_put_stats] pds=", pds, " did=", did, " system_key=", system_key, " token_len=", access_token.length(), " nonce_in='", nonce_holder["value"], "'")
	var existing := await get_record(parent, pds, did, "actor.rpg.stats")
	print("[merge_and_put_stats] existing record keys=", existing.keys())
	var record: Dictionary
	if existing.has("value") and existing["value"] is Dictionary:
		record = (existing["value"] as Dictionary).duplicate(true)
	else:
		record = { "$type": "actor.rpg.stats" }
	record[system_key] = data
	return await put_record(parent, pds, did, "actor.rpg.stats", "self", record, access_token, dpop_key, nonce_holder)


static func pds_from_did(parent: Node, did: String) -> String:
	return await _pds_from_did(parent, did)


# ── private helpers ───────────────────────────────────────────────────────────

static func _pds_from_did(parent: Node, did: String) -> String:
	var url: String
	if did.begins_with("did:plc:"):
		url = "https://plc.directory/" + did.uri_encode()
	elif did.begins_with("did:web:"):
		var domain := did.replace("did:web:", "").replace("%3A", ":").replace("%2F", "/")
		url = "https://%s/.well-known/did.json" % domain
	else:
		return ""
	var r := await _http_raw(parent, url, HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray())
	if r["code"] < 200 or r["code"] >= 300:
		return ""
	var doc = JSON.parse_string(r["body_str"])
	if not doc is Dictionary:
		return ""
	for service in (doc as Dictionary).get("service", []):
		if service.get("id") == "#atproto_pds" or service.get("type") == "AtprotoPersonalDataServer":
			return service.get("serviceEndpoint", "")
	return ""


static func _put_attempt(
	parent: Node,
	url: String,
	body: PackedByteArray,
	access_token: String,
	dpop_key: Dictionary,
	nonce: String,
) -> Dictionary:
	var proof := DpopUtil.create_proof(dpop_key, "POST", url, nonce, access_token)
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: DPoP " + access_token,
		"DPoP: " + proof,
	]
	return await _http_raw(parent, url, HTTPClient.METHOD_POST, headers, body)


static func _extract_dpop_nonce(headers: PackedStringArray) -> String:
	for h: String in headers:
		if h.to_lower().begins_with("dpop-nonce:"):
			return h.split(":", true, 1)[1].strip_edges()
	return ""
