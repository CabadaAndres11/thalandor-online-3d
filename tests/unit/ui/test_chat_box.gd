extends GutTest

var chat: ChatBox


func before_each() -> void:
	chat = ChatBox.new()
	chat.max_length = 120
	add_child_autofree(chat)


func test_enter_opens_and_empty_enter_closes() -> void:
	watch_signals(chat)
	chat.open_input()
	assert_true(chat.is_typing())
	assert_signal_emitted_with_parameters(chat, "typing_changed", [true])
	chat.submit("   ")
	assert_false(chat.is_typing())
	assert_signal_not_emitted(chat, "message_submitted")
	assert_signal_emitted_with_parameters(chat, "typing_changed", [false])


func test_submit_emits_text_and_closes() -> void:
	watch_signals(chat)
	chat.open_input()
	chat.submit("hola")
	assert_signal_emitted_with_parameters(chat, "message_submitted", ["hola"])
	assert_false(chat.is_typing())


func test_cancel_closes_without_sending() -> void:
	watch_signals(chat)
	chat.open_input()
	chat.cancel()
	assert_false(chat.is_typing())
	assert_signal_not_emitted(chat, "message_submitted")


func test_keeps_last_8_messages() -> void:
	for i in 12:
		chat.add_message("Ana", "m%d" % i, false)
	var lines := chat.visible_lines()
	assert_eq(lines.size(), 8)
	assert_true(lines[0].ends_with("m4"))
	assert_true(lines[7].ends_with("m11"))


func test_system_messages_have_no_author() -> void:
	chat.add_message("", "Bea se ha unido al grupo", true)
	assert_eq(chat.visible_lines()[0], "Bea se ha unido al grupo")


func test_long_text_limited() -> void:
	chat.open_input()
	assert_eq(chat.input_max_length(), 120)


func test_bbcode_is_not_interpreted() -> void:
	chat.add_message("Ana", "[b]hola[/b]", false)
	assert_true(chat.visible_lines()[0].contains("[b]hola[/b]"))
