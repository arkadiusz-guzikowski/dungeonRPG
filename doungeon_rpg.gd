extends Node2D


func _ready() -> void:
	var potwory := get_node_or_null("Potwory")
	var walka := get_node_or_null("Walka")
	if potwory and walka:
		potwory.potwor_klikniety.connect(walka.start_walka)