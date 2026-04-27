# DPoP helper extracted from addons/rpg_actor/autoload/atproto_oauth.gd (MIT).
# Stateless — takes a per-slot key dict instead of global _ecdsa_key / _public_jwk.
# Reason: ATProtoOAuth holds a single global keypair; 4 simultaneous logins need
# independent keys that never cross-contaminate each others' DPoP nonce state.
extends RefCounted
class_name DpopUtil


static func generate_keypair() -> Dictionary:
	var crypto := Crypto.new()
	var key: CryptoKey = crypto.generate_rsa(2048)
	var pub_pem := key.save_to_string(true)
	var jwk := _pem_to_jwk(pub_pem)
	return { "crypto": crypto, "key": key, "jwk": jwk }


static func create_proof(slot_key: Dictionary, http_method: String, target_url: String, nonce: String = "", access_token: String = "") -> String:
	var base_url := target_url.split("?")[0]
	var header := { "typ": "dpop+jwt", "alg": "RS256", "jwk": slot_key["jwk"] }
	var payload := {
		"jti": _random_b64u(slot_key["crypto"], 16),
		"htm": http_method,
		"htu": base_url,
		"iat": int(Time.get_unix_time_from_system()),
	}
	if not nonce.is_empty():
		payload["nonce"] = nonce
	# `ath` (access token hash) is required by AT Proto OAuth whenever a DPoP proof
	# accompanies a bearer token — i.e. for any authenticated resource request.
	if not access_token.is_empty():
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(access_token.to_utf8_buffer())
		payload["ath"] = _b64u_bytes(ctx.finish())
	return _sign_jwt(slot_key, header, payload)


static func _sign_jwt(slot_key: Dictionary, header: Dictionary, payload: Dictionary) -> String:
	var h := _b64u_str(JSON.stringify(header))
	var p := _b64u_str(JSON.stringify(payload))
	var signing_input := h + "." + p
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(signing_input.to_utf8_buffer())
	var digest := ctx.finish()
	var sig := (slot_key["crypto"] as Crypto).sign(HashingContext.HASH_SHA256, digest, slot_key["key"])
	return signing_input + "." + _b64u_bytes(sig)


static func _pem_to_jwk(pem: String) -> Dictionary:
	var clean := pem \
		.replace("-----BEGIN PUBLIC KEY-----", "") \
		.replace("-----END PUBLIC KEY-----", "") \
		.replace("-----BEGIN RSA PUBLIC KEY-----", "") \
		.replace("-----END RSA PUBLIC KEY-----", "") \
		.strip_edges().replace("\n", "").replace("\r", "")
	var der := Marshalls.base64_to_raw(clean)
	var params := _extract_rsa_params(der)
	return { "kty": "RSA", "use": "sig", "alg": "RS256",
		"n": _b64u_bytes(params[0]), "e": _b64u_bytes(params[1]) }


static func _extract_rsa_params(der: PackedByteArray) -> Array:
	var pos := _der_skip_tag_length(der, 0)
	pos = _der_skip_tlv(der, pos)
	pos += 1
	var result := _der_read_length(der, pos)
	pos = result[1]
	pos += 1
	pos = _der_skip_tag_length(der, pos)
	pos += 1
	result = _der_read_length(der, pos)
	var n_len: int = result[0]
	pos = result[1]
	var n_bytes := der.slice(pos, pos + n_len)
	if n_bytes.size() > 0 and n_bytes[0] == 0:
		n_bytes = n_bytes.slice(1)
	pos += n_len
	pos += 1
	result = _der_read_length(der, pos)
	var e_len: int = result[0]
	pos = result[1]
	var e_bytes := der.slice(pos, pos + e_len)
	if e_bytes.size() > 0 and e_bytes[0] == 0:
		e_bytes = e_bytes.slice(1)
	return [n_bytes, e_bytes]


static func _der_skip_tag_length(der: PackedByteArray, pos: int) -> int:
	pos += 1
	return _der_read_length(der, pos)[1]


static func _der_skip_tlv(der: PackedByteArray, pos: int) -> int:
	pos += 1
	var r := _der_read_length(der, pos)
	return r[1] + r[0]


static func _der_read_length(der: PackedByteArray, pos: int) -> Array:
	if der[pos] < 0x80:
		return [der[pos], pos + 1]
	var num_bytes := der[pos] & 0x7F
	pos += 1
	var length := 0
	for i in range(num_bytes):
		length = (length << 8) | der[pos]
		pos += 1
	return [length, pos]


static func _random_b64u(crypto: Crypto, byte_length: int) -> String:
	return _b64u_bytes(crypto.generate_random_bytes(byte_length))


static func _b64u_bytes(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").rstrip("=")


static func _b64u_str(text: String) -> String:
	return _b64u_bytes(text.to_utf8_buffer())
