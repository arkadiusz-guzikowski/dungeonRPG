extends Node2D


func _ready() -> void:
	var potwory := get_node_or_null("Potwory")
	var walka := get_node_or_null("Walka")
	if potwory and walka:
		potwory.potwor_klikniety.connect(walka.start_walka)
	$Przyciski/Panel/VBox/MapaButton.pressed.connect(_pokaz_mape)
	$Przyciski/Panel/VBox/KowalButton.pressed.connect(_pokaz_kowala)
	$Ekwipunek.dodaj_przedmiot("Kamien Kowalski")
	_pokaz_mape()


func _pokaz_mape() -> void:
	$Mapa.visible = true
	$Potwory.visible = true
	$Ekwipunek/KowalPanel.visible = false


func _pokaz_kowala() -> void:
	$Mapa.visible = false
	$Potwory.visible = false
	$Ekwipunek/KowalPanel.visible = true
