class_name RtcNoise
## Warnings from libdatachannel (webrtc-native) that are expected and harmless:
## - a channel reset that fails because the other side already closed it;
## - ICE trying routes the machine has no network for (e.g. IPv6 on CI runners).
## GUT fails a test on any engine warning, so WebRTC tests mark these as handled.

const PATTERNS := ["SctpTransport::sendReset", "juice: Send failed"]


static func accept(test: GutTest) -> void:
	for err: Variant in test.get_errors():
		for pattern: String in PATTERNS:
			if err.contains_text(pattern):
				err.handled = true
