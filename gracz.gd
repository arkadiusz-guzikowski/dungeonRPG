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


func _ready() -> void:
	kolo = get_node_or_null("Kolo") as Polygon2D
	label_player = get_node_or_null("PlayerLabel") as Label
	label_hp = get_node_or_null("HpLabel") as Label
	label_obrazenia = get_node_or_null("ObrazeniaLabel") as Label
	_aktualizuj()


func _aktualizuj() -> void:
	if label_player:
		label_player.text = "player"
	if label_hp:
		label_hp.text = "HP %d" % hp
	if label_obrazenia:
		label_obrazenia.text = "obrazenia  %d-%d" % [obrazenia_min, obrazenia_max]


func atakuj() -> int:
	return randi_range(obrazenia_min, obrazenia_max)


func otrzymaj_obrazenia(ilosc: int) -> void:
	hp = maxi(0, hp - ilosc)
	_aktualizuj()
