@tool
extends Node2D

@export var hp: int = 50
@export var hp_max: int = 50
@export var obrazenia_min: int = 1
@export var obrazenia_max: int = 2

var kolo: Polygon2D
var label_player: Label
var label_hp: Label
var label_obrazenia: Label
var label_obrona: Label

var _ekwipunek: CanvasLayer


func _ready() -> void:
	kolo = get_node_or_null("Kolo") as Polygon2D
	label_player = get_node_or_null("PlayerLabel") as Label
	label_hp = get_node_or_null("HpLabel") as Label
	label_obrazenia = get_node_or_null("ObrazeniaLabel") as Label
	label_obrona = get_node_or_null("ObronaLabel") as Label
	_ekwipunek = get_node_or_null("/root/Node2D/Ekwipunek") as CanvasLayer
	if _ekwipunek and not _ekwipunek.ekwipunek_zmieniony.is_connected(_aktualizuj):
		_ekwipunek.ekwipunek_zmieniony.connect(_aktualizuj)
	_aktualizuj()


func _aktualizuj() -> void:
	if label_player:
		label_player.text = "player"
	if label_hp:
		label_hp.text = "HP %d" % hp
	if label_obrazenia:
		var bonus: int = 0
		if _ekwipunek and _ekwipunek.has_method("bonus_obrazenia"):
			bonus = _ekwipunek.bonus_obrazenia()
		label_obrazenia.text = "obrazenia  %d-%d" % [obrazenia_min + bonus, obrazenia_max + bonus]
	if label_obrona:
		var redukcja_label: int = 0
		if _ekwipunek and _ekwipunek.has_method("redukcja_obrazen"):
			redukcja_label = _ekwipunek.redukcja_obrazen()
		label_obrona.text = "obrona  %d" % redukcja_label


func atakuj() -> int:
	var bonus: int = 0
	if _ekwipunek and _ekwipunek.has_method("bonus_obrazenia"):
		bonus = _ekwipunek.bonus_obrazenia()
	return randi_range(obrazenia_min, obrazenia_max) + bonus


func obrona() -> int:
	var redukcja: int = 0
	if _ekwipunek and _ekwipunek.has_method("redukcja_obrazen"):
		redukcja = _ekwipunek.redukcja_obrazen()
	return redukcja


func otrzymaj_obrazenia(ilosc: int) -> void:
	var realne: int = maxi(0, ilosc - obrona())
	hp = maxi(0, hp - realne)
	_aktualizuj()


func lecz(ile: int) -> void:
	hp = mini(hp_max, hp + ile)
	_aktualizuj()
