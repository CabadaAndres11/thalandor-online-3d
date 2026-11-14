extends GutTest


func test_roundtrip() -> void:
	for ip in ["0.0.0.0", "255.255.255.255", "100.101.102.103", "192.168.1.34", "10.0.0.7"]:
		assert_eq(GroupCode.decode(GroupCode.encode(ip)), ip, ip)


func test_format_has_dash() -> void:
	var code := GroupCode.encode("192.168.1.34")
	assert_eq(code.length(), 9)
	assert_eq(code[4], "-")
	for ch in code.replace("-", ""):
		assert_true(GroupCode.ALPHABET.contains(ch), ch)


func test_decode_is_case_and_space_insensitive() -> void:
	var code := GroupCode.encode("100.64.3.9")
	var messy := " " + code.to_lower().replace("-", " ") + " "
	assert_eq(GroupCode.decode(messy), "100.64.3.9")
	assert_eq(GroupCode.decode(code.replace("-", "")), "100.64.3.9")


func test_rejects_wrong_length() -> void:
	assert_eq(GroupCode.decode(""), "")
	assert_eq(GroupCode.decode("ABC-DEF"), "")
	assert_eq(GroupCode.decode("ABCD-EFGHJ"), "")


func test_rejects_ambiguous_chars() -> void:
	var code := GroupCode.encode("192.168.1.34").replace("-", "")
	for bad in ["O", "0", "I", "1", "L"]:
		assert_eq(GroupCode.decode(bad + code.substr(1)), "", bad)


func test_rejects_bad_checksum() -> void:
	var code := GroupCode.encode("192.168.1.34").replace("-", "")
	var last := code[7]
	var other := "2" if last != "2" else "3"
	assert_eq(GroupCode.decode(code.substr(0, 7) + other), "")


func test_rejects_value_out_of_range() -> void:
	# All 'Z' (max digit) with a matching checksum encodes a number > 2^32 - 1.
	var digits := "ZZZZZZZ"
	var check := GroupCode.ALPHABET[(30 * 7) % 31]
	assert_eq(GroupCode.decode(digits + check), "")


func test_pick_prefers_tailscale() -> void:
	var ips := PackedStringArray(["127.0.0.1", "192.168.1.20", "100.88.1.2", "fe80::1"])
	assert_eq(GroupCode.pick_host_ip(ips), "100.88.1.2")


func test_pick_falls_back_to_lan() -> void:
	assert_eq(GroupCode.pick_host_ip(PackedStringArray(["127.0.0.1", "10.1.2.3"])), "10.1.2.3")
	assert_eq(GroupCode.pick_host_ip(PackedStringArray(["172.20.0.5"])), "172.20.0.5")
	assert_eq(GroupCode.pick_host_ip(PackedStringArray(["172.32.0.5", "192.168.0.9"])), "192.168.0.9")


func test_pick_ignores_loopback_linklocal_ipv6() -> void:
	assert_eq(GroupCode.pick_host_ip(PackedStringArray(["127.0.0.1", "169.254.3.3", "::1", "fe80::2"])), "")


func test_pick_ignores_cgnat_outside_tailscale_range() -> void:
	assert_eq(GroupCode.pick_host_ip(PackedStringArray(["100.128.0.1"])), "")


func test_pick_returns_empty_when_none() -> void:
	assert_eq(GroupCode.pick_host_ip(PackedStringArray()), "")
