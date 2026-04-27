# QR Code encoder — GDScript port of Nayuki's QR Code generator (MIT License).
# Original: https://github.com/nayuki/QR-Code-generator  Copyright (c) Project Nayuki
# This port: MIT License, same terms.
#
# Usage:
#   var matrix: Array = QrEncoder.encode_url(url)
#   # matrix[y][x] == true  → dark module
#   # matrix.size() gives the side length (same for rows and columns)
class_name QrEncoder

# ECC level ordinals: 0=Low 1=Medium 2=Quartile 3=High
const ECC_LOW      := 0
const ECC_MEDIUM   := 1
const ECC_QUARTILE := 2
const ECC_HIGH     := 3

# formatbits for each ECC level (written into the format info word)
const _ECC_FORMAT_BITS := [1, 0, 3, 2]

# ECC codewords per block [ecc_level][version 1..40]  (index 0 unused, padded with -1)
const _ECC_CODEWORDS_PER_BLOCK: Array = [
	[-1, 7,10,15,20,26,18,20,24,30,18,20,24,26,30,22,24,28,30,28,28,28,28,30,30,26,28,30,30,30,30,30,30,30,30,30,30,30,30,30,30],
	[-1,10,16,26,18,24,16,18,22,22,26,30,22,22,24,24,28,28,26,26,26,26,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28],
	[-1,13,22,18,26,18,24,18,22,20,24,28,26,24,20,30,24,28,28,26,30,28,30,30,30,30,28,30,30,30,30,30,30,30,30,30,30,30,30,30,30],
	[-1,17,28,22,16,22,28,26,26,24,28,24,28,22,24,24,30,28,28,26,28,30,24,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30],
]

# Number of ECC blocks [ecc_level][version 1..40]
const _NUM_ECC_BLOCKS: Array = [
	[-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9,10,12,12,12,13,14,15,16,17,18,19,19,20,21,22,24,25],
	[-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9,10,10,11,13,14,16,17,17,18,20,21,23,25,26,28,29,31,33,35,37,38,40,43,45,47,49],
	[-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8,10,12,16,12,17,16,18,21,20,23,23,25,27,29,34,34,35,38,40,43,45,48,51,53,56,59,62,65,68],
	[-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8,11,11,16,16,18,16,19,21,25,25,25,34,30,32,35,37,40,42,45,48,51,54,57,60,63,66,70,74,77,81],
]

# Byte-mode char-count bit widths per version group: versions 1-9, 10-26, 27-40
const _BYTE_MODE_BITS := 0x4
const _BYTE_CHAR_COUNT_BITS := [8, 16, 16]

# Penalty rule constants (from the QR spec)
const _PENALTY_N1 := 3
const _PENALTY_N2 := 3
const _PENALTY_N3 := 40
const _PENALTY_N4 := 10


# Encode a URL string and return the QR module matrix.
# Returns Array[Array[bool]]  where matrix[y][x] is true for dark.
# ECC level defaults to Medium — handles ~15% damage, good balance for screen display.
static func encode_url(url: String, ecc: int = ECC_MEDIUM) -> Array:
	var data: PackedByteArray = url.to_utf8_buffer()
	return _encode_bytes(data, ecc)


static func _encode_bytes(data: PackedByteArray, ecc: int) -> Array:
	# Find the minimum version that fits the data in byte mode.
	var version := -1
	for v in range(1, 41):
		var capacity := _get_num_data_codewords(v, ecc) * 8
		var needed := _get_segment_bits(data.size(), v)
		if needed != -1 and needed <= capacity:
			version = v
			break

	if version == -1:
		push_error("QrEncoder: data too large to encode in any QR version (max v40)")
		return []

	# Build the bit stream: mode indicator + char count + data bytes + terminator + padding.
	var bits: PackedByteArray = _build_bit_stream(data, version, ecc)

	# Build the full codeword sequence with ECC and interleaving.
	var all_cw: PackedByteArray = _add_ecc_and_interleave(bits, version, ecc)

	# Place modules into the matrix and select the best mask.
	return _build_matrix(all_cw, version, ecc)


# Returns the total bit count needed for one byte-mode segment at the given version,
# or -1 if the character count overflows the char-count field.
static func _get_segment_bits(byte_count: int, version: int) -> int:
	var cc_bits: int = _BYTE_CHAR_COUNT_BITS[(version + 7) / 17]
	if byte_count >= (1 << cc_bits):
		return -1
	return 4 + cc_bits + byte_count * 8


static func _get_num_raw_data_modules(ver: int) -> int:
	var result: int = (16 * ver + 128) * ver + 64
	if ver >= 2:
		var numalign: int = ver / 7 + 2
		result -= (25 * numalign - 10) * numalign - 55
	if ver >= 7:
		result -= 36
	return result


static func _get_num_data_codewords(ver: int, ecc: int) -> int:
	return _get_num_raw_data_modules(ver) / 8 \
		- _ECC_CODEWORDS_PER_BLOCK[ecc][ver] \
		* _NUM_ECC_BLOCKS[ecc][ver]


# Pack data into the padded byte sequence that fills the data codeword capacity.
static func _build_bit_stream(data: PackedByteArray, version: int, ecc: int) -> PackedByteArray:
	var total_cw := _get_num_data_codewords(version, ecc)
	var total_bits := total_cw * 8
	var cc_bits: int = _BYTE_CHAR_COUNT_BITS[(version + 7) / 17]

	# Accumulate bits MSB-first into bytes.
	var out := PackedByteArray()
	var bit_buf := 0
	var bit_len := 0

	# Inline bit-appender — GDScript closures share captured ints by value so
	# we can't reliably mutate bit_buf/bit_len from inside a lambda.  Build a
	# flat list of (value, bit_count) pairs and process them in one loop instead.
	var segments: Array = [
		[_BYTE_MODE_BITS, 4],
		[data.size(), cc_bits],
	]
	for b in data:
		segments.append([b, 8])

	for seg in segments:
		var val: int = seg[0]
		var n: int = seg[1]
		for i in range(n - 1, -1, -1):
			bit_buf = (bit_buf << 1) | ((val >> i) & 1)
			bit_len += 1
			if bit_len == 8:
				out.append(bit_buf & 0xFF)
				bit_buf = 0
				bit_len = 0

	# Terminator: up to 4 zero bits
	var used_bits: int = out.size() * 8 + bit_len
	var term_bits := mini(4, total_bits - used_bits)
	for _i in range(term_bits):
		bit_buf = bit_buf << 1
		bit_len += 1
		if bit_len == 8:
			out.append(bit_buf & 0xFF)
			bit_buf = 0
			bit_len = 0

	# Pad to byte boundary
	if bit_len > 0:
		out.append((bit_buf << (8 - bit_len)) & 0xFF)

	# Pad with alternating 0xEC / 0x11 to fill remaining capacity
	var pad := 0
	while out.size() < total_cw:
		out.append(0xEC if pad == 0 else 0x11)
		pad = 1 - pad

	return out


# --- Reed-Solomon -----------------------------------------------------------

static func _rs_multiply(x: int, y: int) -> int:
	# GF(2^8) multiply mod 0x11D (the QR generator polynomial)
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ (0x11D if (z >> 7) != 0 else 0)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF


static func _rs_compute_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for _i in range(degree):
		for j in range(degree):
			result[j] = _rs_multiply(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _rs_multiply(root, 0x02)
	return result


static func _rs_compute_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b in data:
		var factor: int = b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in range(divisor.size()):
			result[i] ^= _rs_multiply(divisor[i], factor)
	return result


static func _add_ecc_and_interleave(data: PackedByteArray, version: int, ecc: int) -> PackedByteArray:
	var num_blocks: int = _NUM_ECC_BLOCKS[ecc][version]
	var block_ecc_len: int = _ECC_CODEWORDS_PER_BLOCK[ecc][version]
	var raw_cw: int = _get_num_raw_data_modules(version) / 8
	var num_short_blocks: int = num_blocks - raw_cw % num_blocks
	var short_block_len: int = raw_cw / num_blocks

	var blocks: Array = []
	var rsdiv: PackedByteArray = _rs_compute_divisor(block_ecc_len)
	var k := 0
	for i in range(num_blocks):
		var dat_len: int = short_block_len - block_ecc_len + (0 if i < num_short_blocks else 1)
		var dat: PackedByteArray = data.slice(k, k + dat_len)
		k += dat_len
		var ecc_bytes: PackedByteArray = _rs_compute_remainder(dat, rsdiv)
		if i < num_short_blocks:
			dat.append(0)
		# Combine dat + ecc into one block
		var block := PackedByteArray()
		block.append_array(dat)
		block.append_array(ecc_bytes)
		blocks.append(block)

	var result := PackedByteArray()
	for i in range((blocks[0] as PackedByteArray).size()):
		for j in range(blocks.size()):
			var blk: PackedByteArray = blocks[j]
			# Skip the padding byte inserted into short blocks at the data/ecc boundary
			if i == short_block_len - block_ecc_len and j < num_short_blocks:
				continue
			result.append(blk[i])
	return result


# --- Matrix building --------------------------------------------------------

static func _build_matrix(data: PackedByteArray, version: int, ecc: int) -> Array:
	var size: int = version * 4 + 17
	# modules[y][x]: true = dark.  isfunction[y][x]: true = function pattern, skip for data.
	var modules: Array = []
	var isfunction: Array = []
	for _i in range(size):
		modules.append(Array())
		isfunction.append(Array())
		modules[-1].resize(size)
		isfunction[-1].resize(size)
		for x in range(size):
			modules[-1][x] = false
			isfunction[-1][x] = false

	_draw_function_patterns(modules, isfunction, version, ecc, size)
	_draw_codewords(modules, isfunction, data, size)

	# Try all 8 masks, keep the one with the lowest penalty score.
	var best_mask := 0
	var best_penalty: int = 1 << 30
	for mask in range(8):
		_apply_mask(modules, isfunction, mask, size)
		_draw_format_bits(modules, isfunction, version, ecc, mask, size)
		var penalty: int = _get_penalty_score(modules, size)
		if penalty < best_penalty:
			best_mask = mask
			best_penalty = penalty
		# Un-apply to restore state for the next iteration
		_apply_mask(modules, isfunction, mask, size)

	# Apply the winning mask permanently
	_apply_mask(modules, isfunction, best_mask, size)
	_draw_format_bits(modules, isfunction, version, ecc, best_mask, size)

	return modules


static func _set_module(modules: Array, isfunction: Array, x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	isfunction[y][x] = true


static func _draw_function_patterns(modules: Array, isfunction: Array, version: int, ecc: int, size: int) -> void:
	# Timing strips
	for i in range(size):
		_set_module(modules, isfunction, 6, i, i % 2 == 0)
		_set_module(modules, isfunction, i, 6, i % 2 == 0)

	# Finder patterns (top-left, top-right, bottom-left)
	_draw_finder(modules, isfunction, 3, 3, size)
	_draw_finder(modules, isfunction, size - 4, 3, size)
	_draw_finder(modules, isfunction, 3, size - 4, size)

	# Alignment patterns (skip if they would overlap a finder)
	var aligns: Array = _get_alignment_positions(version)
	var n: int = aligns.size()
	for i in range(n):
		for j in range(n):
			# The three corners that overlap finder patterns
			if i == 0 and j == 0:
				continue
			if i == 0 and j == n - 1:
				continue
			if i == n - 1 and j == 0:
				continue
			_draw_alignment(modules, isfunction, aligns[i], aligns[j])

	# Dark module and format/version placeholders (filled last)
	_draw_format_bits(modules, isfunction, version, ecc, 0, size)
	_draw_version_bits(modules, isfunction, version, size)


static func _draw_finder(modules: Array, isfunction: Array, cx: int, cy: int, size: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var xx := cx + dx
			var yy := cy + dy
			if xx >= 0 and xx < size and yy >= 0 and yy < size:
				var dist := maxi(absi(dx), absi(dy))
				_set_module(modules, isfunction, xx, yy, dist != 2 and dist != 4)


static func _draw_alignment(modules: Array, isfunction: Array, cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_module(modules, isfunction, cx + dx, cy + dy, maxi(absi(dx), absi(dy)) != 1)


static func _get_alignment_positions(version: int) -> Array:
	if version == 1:
		return []
	var numalign: int = version / 7 + 2
	# Step is rounded to an even number so that the last position lands exactly at size-7.
	var step: int = (version * 8 + numalign * 3 + 5) / (numalign * 4 - 4) * 2
	var last: int = version * 4 + 10  # = size - 7
	# Build descending list [last, last-step, …] of length numalign-1, then append 6, then reverse.
	var result: Array = []
	for i in range(numalign - 1):
		result.append(last - i * step)
	result.append(6)
	result.reverse()
	return result


static func _draw_format_bits(modules: Array, isfunction: Array, _version: int, ecc: int, mask: int, size: int) -> void:
	var data: int = _ECC_FORMAT_BITS[ecc] << 3 | mask
	var rem: int = data
	for _i in range(10):
		rem = (rem << 1) ^ (0x537 if (rem >> 9) != 0 else 0)
	var bits: int = (data << 10 | rem) ^ 0x5412

	# Bottom-left and top-right copies of the format info
	for i in range(6):
		_set_module(modules, isfunction, 8, i, _get_bit(bits, i))
	_set_module(modules, isfunction, 8, 7, _get_bit(bits, 6))
	_set_module(modules, isfunction, 8, 8, _get_bit(bits, 7))
	_set_module(modules, isfunction, 7, 8, _get_bit(bits, 8))
	for i in range(9, 15):
		_set_module(modules, isfunction, 14 - i, 8, _get_bit(bits, i))

	for i in range(8):
		_set_module(modules, isfunction, size - 1 - i, 8, _get_bit(bits, i))
	for i in range(8, 15):
		_set_module(modules, isfunction, 8, size - 15 + i, _get_bit(bits, i))
	# The always-dark module
	_set_module(modules, isfunction, 8, size - 8, true)


static func _draw_version_bits(modules: Array, isfunction: Array, version: int, size: int) -> void:
	if version < 7:
		return
	var rem: int = version
	for _i in range(12):
		rem = (rem << 1) ^ (0x1F25 if (rem >> 11) != 0 else 0)
	var bits: int = version << 12 | rem
	for i in range(18):
		var bit: bool = _get_bit(bits, i)
		var a: int = size - 11 + i % 3
		var b: int = i / 3
		_set_module(modules, isfunction, a, b, bit)
		_set_module(modules, isfunction, b, a, bit)


static func _draw_codewords(modules: Array, isfunction: Array, data: PackedByteArray, size: int) -> void:
	var i := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right -= 1  # skip the vertical timing column
		for vert in range(size):
			for j in range(2):
				var x: int = right - j
				var upward: bool = ((right + 1) & 2) == 0
				var y: int = (size - 1 - vert) if upward else vert
				if not isfunction[y][x] and i < data.size() * 8:
					modules[y][x] = _get_bit(data[i >> 3], 7 - (i & 7))
					i += 1
		right -= 2


static func _apply_mask(modules: Array, isfunction: Array, mask: int, size: int) -> void:
	for y in range(size):
		for x in range(size):
			if isfunction[y][x]:
				continue
			var invert: bool
			match mask:
				0: invert = (x + y) % 2 == 0
				1: invert = y % 2 == 0
				2: invert = x % 3 == 0
				3: invert = (x + y) % 3 == 0
				4: invert = (x / 3 + y / 2) % 2 == 0
				5: invert = x * y % 2 + x * y % 3 == 0
				6: invert = (x * y % 2 + x * y % 3) % 2 == 0
				7: invert = ((x + y) % 2 + x * y % 3) % 2 == 0
				_: invert = false
			if invert:
				modules[y][x] = not modules[y][x]


static func _get_penalty_score(modules: Array, size: int) -> int:
	var result := 0

	# N1: runs of ≥5 same-color in rows and columns
	for y in range(size):
		var run_color := false
		var run_len := 0
		for x in range(size):
			if modules[y][x] == run_color:
				run_len += 1
				if run_len == 5:
					result += _PENALTY_N1
				elif run_len > 5:
					result += 1
			else:
				run_color = modules[y][x]
				run_len = 1
	for x in range(size):
		var run_color := false
		var run_len := 0
		for y in range(size):
			if modules[y][x] == run_color:
				run_len += 1
				if run_len == 5:
					result += _PENALTY_N1
				elif run_len > 5:
					result += 1
			else:
				run_color = modules[y][x]
				run_len = 1

	# N2: 2×2 blocks of same color
	for y in range(size - 1):
		for x in range(size - 1):
			var c: bool = modules[y][x]
			if c == modules[y][x+1] and c == modules[y+1][x] and c == modules[y+1][x+1]:
				result += _PENALTY_N2

	# N3: finder-pattern lookalike: 1011101 flanked by 4 whites on either side
	for y in range(size):
		var run_color := false
		var run_len := 0
		var hist := [0, 0, 0, 0, 0, 0, 0]
		for x in range(size):
			if modules[y][x] == run_color:
				run_len += 1
			else:
				_fp_add_history(hist, run_len, size)
				if not run_color:
					result += _fp_count_patterns(hist) * _PENALTY_N3
				run_color = modules[y][x]
				run_len = 1
		result += _fp_terminate(run_color, run_len, hist, size) * _PENALTY_N3

	for x in range(size):
		var run_color := false
		var run_len := 0
		var hist := [0, 0, 0, 0, 0, 0, 0]
		for y in range(size):
			if modules[y][x] == run_color:
				run_len += 1
			else:
				_fp_add_history(hist, run_len, size)
				if not run_color:
					result += _fp_count_patterns(hist) * _PENALTY_N3
				run_color = modules[y][x]
				run_len = 1
		result += _fp_terminate(run_color, run_len, hist, size) * _PENALTY_N3

	# N4: dark/light balance penalty
	var dark := 0
	for y in range(size):
		for x in range(size):
			if modules[y][x]:
				dark += 1
	var total: int = size * size
	var k: int = (absi(dark * 20 - total * 10) + total - 1) / total - 1
	result += k * _PENALTY_N4

	return result


static func _fp_add_history(hist: Array, run_len: int, size: int) -> void:
	if hist[0] == 0:
		run_len += size
	hist.pop_back()
	hist.insert(0, run_len)


static func _fp_count_patterns(hist: Array) -> int:
	var n: int = hist[1]
	if n <= 0:
		return 0
	var core: bool = hist[2] == n and hist[3] == n * 3 and hist[4] == n and hist[5] == n
	var count := 0
	if core and hist[0] >= n * 4 and hist[6] >= n:
		count += 1
	if core and hist[6] >= n * 4 and hist[0] >= n:
		count += 1
	return count


static func _fp_terminate(run_color: bool, run_len: int, hist: Array, size: int) -> int:
	_fp_add_history(hist, run_len, size)
	if not run_color:
		_fp_add_history(hist, 0, size)
		return _fp_count_patterns(hist)
	_fp_add_history(hist, 0, size)
	_fp_add_history(hist, 0, size)
	return _fp_count_patterns(hist)


static func _get_bit(val: int, index: int) -> bool:
	return ((val >> index) & 1) != 0
