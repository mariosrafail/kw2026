extends RefCounted
class_name LobbyChatController

const PIXEL_FONT_REGULAR := preload("res://assets/fonts/pixel_operator/PixelOperator.ttf")
const PIXEL_FONT_BOLD := preload("res://assets/fonts/pixel_operator/PixelOperator-Bold.ttf")
const MAX_CHAT_CHARS := 140
const MAX_MESSAGES_PER_LOBBY := 60

var _send_message_cb: Callable = Callable()
var _views: Dictionary = {}
var _messages_by_lobby: Dictionary = {}
var _active_lobby_id := 0

func configure(send_message_cb: Callable) -> void:
	_send_message_cb = send_message_cb

func bind_view(view_id: String, list: RichTextLabel, input: LineEdit, send_button: BaseButton = null) -> void:
	if view_id.strip_edges().is_empty():
		return
	if list == null or input == null:
		return
	list.bbcode_enabled = false
	list.fit_content = false
	list.scroll_active = true
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.selection_enabled = false
	list.add_theme_font_override("normal_font", PIXEL_FONT_REGULAR)
	list.add_theme_font_override("bold_font", PIXEL_FONT_BOLD)
	list.add_theme_font_size_override("normal_font_size", 8)
	list.add_theme_font_size_override("bold_font_size", 8)
	list.add_theme_color_override("default_color", Color(0.88, 0.93, 1.0, 0.95))
	list.add_theme_constant_override("outline_size", 0)
	list.scroll_following = true

	input.max_length = MAX_CHAT_CHARS
	input.placeholder_text = "Type a message..."
	input.add_theme_font_override("font", PIXEL_FONT_REGULAR)
	input.add_theme_font_size_override("font_size", 8)
	input.focus_mode = Control.FOCUS_ALL
	for prop_value in input.get_property_list():
		if not (prop_value is Dictionary):
			continue
		var prop := prop_value as Dictionary
		if str(prop.get("name", "")) == "keep_editing_on_text_submit":
			input.set("keep_editing_on_text_submit", true)
			break
	if send_button != null:
		send_button.focus_mode = Control.FOCUS_NONE

	var data := {
		"list": list,
		"input": input,
		"send": send_button
	}
	_views[view_id] = data

	var submit_input_cb := func(_submitted_text: String) -> void:
		_submit_from_view(view_id)
	var sanitize_input_cb := func(new_text: String) -> void:
		var sanitized := _sanitize_english_text(new_text)
		if sanitized == new_text:
			return
		input.text = sanitized
		input.caret_column = sanitized.length()
	input.text_submitted.connect(submit_input_cb)
	input.text_changed.connect(sanitize_input_cb)
	if send_button != null:
		var submit_button_cb := func() -> void:
			_submit_from_view(view_id)
		send_button.pressed.connect(submit_button_cb)

	_render_view(view_id)

func set_active_lobby(lobby_id: int) -> void:
	var normalized := maxi(0, lobby_id)
	if normalized == _active_lobby_id:
		return
	_active_lobby_id = normalized
	_render_all_views()

func clear_active_input() -> void:
	for view_data_value in _views.values():
		if not (view_data_value is Dictionary):
			continue
		var view_data := view_data_value as Dictionary
		var input := view_data.get("input", null) as LineEdit
		if input != null:
			input.text = ""

func append_message(lobby_id: int, display_name: String, message: String) -> void:
	var normalized_lobby_id := maxi(0, lobby_id)
	if normalized_lobby_id <= 0:
		return
	var safe_name := display_name.strip_edges()
	if safe_name.is_empty():
		safe_name = "Player"
	var safe_message := message.strip_edges()
	if safe_message.is_empty():
		return
	if safe_message.length() > MAX_CHAT_CHARS:
		safe_message = safe_message.substr(0, MAX_CHAT_CHARS)
	var rows: Array = _messages_by_lobby.get(normalized_lobby_id, []) as Array
	rows.append({
		"name": safe_name,
		"text": safe_message
	})
	if rows.size() > MAX_MESSAGES_PER_LOBBY:
		rows = rows.slice(rows.size() - MAX_MESSAGES_PER_LOBBY, rows.size())
	_messages_by_lobby[normalized_lobby_id] = rows
	if normalized_lobby_id == _active_lobby_id:
		_render_all_views()

func clear_lobby(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	_messages_by_lobby.erase(lobby_id)
	if _active_lobby_id == lobby_id:
		_render_all_views()

func _submit_from_view(view_id: String) -> void:
	var view_data := _views.get(view_id, {}) as Dictionary
	if view_data.is_empty():
		return
	var input := view_data.get("input", null) as LineEdit
	if input == null:
		return
	var text := _sanitize_english_text(input.text).strip_edges()
	if text.is_empty():
		return
	if text.length() > MAX_CHAT_CHARS:
		text = text.substr(0, MAX_CHAT_CHARS)
	if _send_message_cb.is_valid():
		var sent := bool(_send_message_cb.call(text))
		if sent:
			input.text = ""
			input.caret_column = 0
			input.call_deferred("grab_focus")

func _render_all_views() -> void:
	for key in _views.keys():
		_render_view(str(key))

func _render_view(view_id: String) -> void:
	var view_data := _views.get(view_id, {}) as Dictionary
	if view_data.is_empty():
		return
	var list := view_data.get("list", null) as RichTextLabel
	var input := view_data.get("input", null) as LineEdit
	var send_button := view_data.get("send", null) as BaseButton
	if list == null:
		return
	var restore_input_focus := false
	if input != null:
		restore_input_focus = input.has_focus()
	list.clear()

	var can_send := _active_lobby_id > 0 and _send_message_cb.is_valid()
	if input != null:
		input.editable = can_send
		if not can_send:
			input.placeholder_text = "Join a lobby room to chat..."
		else:
			input.placeholder_text = "Type a message..."
	if send_button != null:
		send_button.disabled = not can_send
	if restore_input_focus and can_send and input != null:
		input.call_deferred("grab_focus")

	if _active_lobby_id <= 0:
		list.add_text("No active lobby.")
		return
	var rows := _messages_by_lobby.get(_active_lobby_id, []) as Array
	if rows.is_empty():
		list.add_text("No messages yet.")
		return
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row := row_value as Dictionary
		var sender := str(row.get("name", "Player")).strip_edges()
		var body := str(row.get("text", "")).strip_edges()
		if sender.is_empty():
			sender = "Player"
		list.push_font(PIXEL_FONT_BOLD)
		list.append_text(sender)
		list.pop()
		list.append_text(": %s\n" % body)
	list.scroll_to_line(maxi(0, list.get_line_count() - 1))

func _sanitize_english_text(value: String) -> String:
	if value.is_empty():
		return ""
	var out := ""
	for i in range(value.length()):
		var code := value.unicode_at(i)
		# Keep printable ASCII only (English letters/numbers/symbols/space).
		if code >= 32 and code <= 126:
			out += char(code)
	return out
