extends RefCounted


func prompt_purchase_skin(host: Node, character_id: String, skin_index: int, skin_label: String) -> void:
	var auth_token: String = str(host.get("auth_token")).strip_edges()
	if auth_token.is_empty():
		host.call("_show_auth_panel", true)
		host.call("_set_auth_status", "Auth: login first")
		return

	host.set("_purchase_pending_character_id", host.call("_normalize_character_id", character_id))
	host.set("_purchase_pending_skin_index", maxi(0, skin_index))

	var cleaned: String = skin_label.replace(" [LOCKED]", "")
	var paren: int = cleaned.find(" (")
	if paren >= 0:
		cleaned = cleaned.substr(0, paren)
	cleaned = cleaned.strip_edges()
	host.set("_purchase_pending_skin_name", cleaned)

	var purchase_text: Label = host.get("purchase_text") as Label
	if purchase_text != null:
		var cost: int = int(host.call("_skin_cost_coins", character_id, skin_index))
		purchase_text.text = "Skin: %s\nCost: %d Coins" % [cleaned, cost]

	var purchase_buy_button: Button = host.get("purchase_buy_button") as Button
	if purchase_buy_button != null:
		purchase_buy_button.disabled = false
	host.call("_show_purchase_menu", true)

func on_purchase_buy_pressed(host: Node) -> void:
	if bool(host.get("_purchase_inflight")):
		return
	var pending_character_id: String = str(host.get("_purchase_pending_character_id"))
	var pending_skin_index: int = int(host.get("_purchase_pending_skin_index"))
	if pending_character_id.is_empty() or pending_skin_index <= 0:
		return
	api_purchase_skin(host, pending_character_id, pending_skin_index)

func on_purchase_cancel_pressed(host: Node) -> void:
	host.set("_purchase_pending_character_id", "")
	host.set("_purchase_pending_skin_index", 0)
	host.set("_purchase_pending_skin_name", "")
	host.call("_show_purchase_menu", false)

func api_purchase_skin(host: Node, character_id: String, skin_index: int) -> void:
	if bool(host.get("_auth_inflight")):
		return
	var auth_request: HTTPRequest = host.get("auth_request") as HTTPRequest
	if auth_request == null:
		return
	var token: String = str(host.get("auth_token")).strip_edges()
	if token.is_empty():
		return

	host.set("_purchase_inflight", true)
	var purchase_buy_button: Button = host.get("purchase_buy_button") as Button
	if purchase_buy_button != null:
		purchase_buy_button.disabled = true
	host.call("_set_loading", true, "PROCESSING...")

	host.set("_auth_inflight", true)
	host.set("_auth_pending_action", "purchase_skin")
	var auth_api_base_url: String = str(host.call("_auth_api_base_url"))
	var url: String = "%s/purchase/skin" % auth_api_base_url
	host.call(
		"_append_log",
		"[AUTH][purchase_skin] request user=%s char=%s skin=%d coins_ui=%d" % [
			str(host.get("auth_username")),
			character_id,
			skin_index,
			int(host.get("wallet_coins"))
		]
	)
	var headers: PackedStringArray = PackedStringArray([
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json"
	])
	var body: String = JSON.stringify({"character_id": character_id, "skin_index": skin_index})
	var err: int = auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		host.set("_purchase_inflight", false)
		host.set("_auth_inflight", false)
		host.set("_auth_pending_action", "")
		host.call("_set_loading", false)
		if purchase_buy_button != null:
			purchase_buy_button.disabled = false
