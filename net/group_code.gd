class_name GroupCode
extends RefCounted
## Short group codes for ENet: the host's IPv4 in 7 base-31 symbols plus 1 check symbol,
## shown as "ABCD-EFGH". The port is fixed (Balance.port).

const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const BASE := 31
const DATA_LEN := 7
const MAX_IP := 4294967295


static func encode(ip: String) -> String:
	var value := _ip_to_int(ip)
	var digits := ""
	var sum := 0
	for i in DATA_LEN:
		var d := value % BASE
		value /= BASE
		digits = ALPHABET[d] + digits
		sum += d
	var raw := digits + ALPHABET[sum % BASE]
	return raw.substr(0, 4) + "-" + raw.substr(4)


## Returns the IPv4 address, or "" if the code is invalid.
static func decode(code: String) -> String:
	var raw := code.to_upper().replace(" ", "").replace("-", "").strip_edges()
	if raw.length() != DATA_LEN + 1:
		return ""
	var value := 0
	var sum := 0
	for i in DATA_LEN:
		var d := ALPHABET.find(raw[i])
		if d < 0:
			return ""
		value = value * BASE + d
		sum += d
	var check := ALPHABET.find(raw[DATA_LEN])
	if check < 0 or check != sum % BASE or value > MAX_IP:
		return ""
	return "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]


## Best address for friends to reach this PC: Tailscale (100.64.0.0/10) first,
## then private LAN ranges. Ignores IPv6, loopback and link-local. "" if none.
static func pick_host_ip(addresses: PackedStringArray) -> String:
	var lan := ""
	for ip in addresses:
		var parts := ip.split(".")
		if parts.size() != 4 or not ip.is_valid_ip_address():
			continue
		var a := int(parts[0])
		var b := int(parts[1])
		if a == 100 and b >= 64 and b <= 127:
			return ip
		if lan == "" and (a == 10 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31)):
			lan = ip
	return lan


static func _ip_to_int(ip: String) -> int:
	var parts := ip.split(".")
	var value := 0
	for p in parts:
		value = (value << 8) | (int(p) & 255)
	return value
