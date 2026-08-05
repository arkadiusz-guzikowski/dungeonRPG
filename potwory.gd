@tool
extends Node2D

signal potwor_klikniety(potwor: Polygon2D)

const KOLOR_ZOMBI := Color(0.8, 0, 0, 1)
const KOLOR_GHUL := Color(0, 0.3, 1, 1)
const KOLOR_SKELETON := Color(0.5, 0.5, 0.5, 1)
const KOLOR_CHAMPION := Color(1, 0, 0, 1)

const STATYSTYKI := {
	KOLOR_ZOMBI: {"nazwa": "Zombi", "hp": 15, "obrazenia_min": 1, "obrazenia_max": 2},
	KOLOR_GHUL: {"nazwa": "Ghul", "hp": 10, "obrazenia_min": 1, "obrazenia_max": 3},
	KOLOR_SKELETON: {"nazwa": "Skeleton", "hp": 10, "obrazenia_min": 1, "obrazenia_max": 2},
}

@export var czas_niewidoczny: float = 5.0
@export var czas_widoczny: float = 10.0

var male_potwory: Array[Polygon2D] = []
var champion: Polygon2D


func _ready() -> void:
	_pobierz_wezly()
	randomize()
	_losuj_typy()
	_losuj_pozycje()
	if Engine.is_editor_hint():
		return
	champion.visible = false
	_petla_championa()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var klik := get_global_mouse_position()
		var trafiony: Polygon2D = null
		var min_odleglosc := INF
		var potwory: Array[Polygon2D] = male_potwory.duplicate()
		if champion and champion.visible:
			potwory.append(champion)
		for potwor in potwory:
			if potwor and potwor.visible:
				var odleglosc: float = potwor.global_position.distance_to(klik)
				if odleglosc <= _rozmiar_potwora(potwor) * 1.5 and odleglosc < min_odleglosc:
					min_odleglosc = odleglosc
					trafiony = potwor
		if trafiony:
			potwor_klikniety.emit(trafiony)


func _pobierz_wezly() -> void:
	male_potwory.clear()
	for dziecko in get_children():
		if dziecko is Polygon2D and dziecko.name != "WiekszyPotwor":
			male_potwory.append(dziecko)
	champion = get_node_or_null("WiekszyPotwor") as Polygon2D


func _losuj_typy() -> void:
	var typy: Array[Color] = [KOLOR_ZOMBI, KOLOR_GHUL, KOLOR_SKELETON]
	for potwor in male_potwory:
		if potwor:
			potwor.color = typy[randi() % typy.size()]


func _losuj_pozycje() -> void:
	for potwor in male_potwory:
		if potwor:
			potwor.position = _losowa_pozycja(_rozmiar_potwora(potwor))


func _rozmiar_mapy() -> Vector2:
	var mapa := get_node_or_null("../Mapa") as Polygon2D
	if mapa and mapa.polygon.size() >= 4:
		var p0: Vector2 = mapa.polygon[0]
		var p1: Vector2 = mapa.polygon[1]
		var p2: Vector2 = mapa.polygon[2]
		return Vector2(
			maxf(p0.x, maxf(p1.x, p2.x)) - minf(p0.x, minf(p1.x, p2.x)),
			maxf(p0.y, maxf(p1.y, p2.y)) - minf(p0.y, minf(p1.y, p2.y))
		)
	return Vector2(900, 600)


func _losowa_pozycja(rozmiar_potwora: float) -> Vector2:
	var rozmiar := _rozmiar_mapy()
	var max_x: float = maxf(0.0, rozmiar.x - rozmiar_potwora)
	var max_y: float = maxf(0.0, rozmiar.y - rozmiar_potwora)
	return Vector2(randf_range(0, max_x), randf_range(0, max_y))


func _rozmiar_potwora(potwor: Polygon2D) -> float:
	if potwor.polygon.size() >= 2:
		return maxf(potwor.polygon[1].x, potwor.polygon[1].y)
	return 5.0


func _petla_championa() -> void:
	while true:
		await get_tree().create_timer(czas_niewidoczny).timeout
		if champion:
			champion.position = _losowa_pozycja(_rozmiar_potwora(champion))
			champion.visible = true
		await get_tree().create_timer(czas_widoczny).timeout
		if champion:
			champion.visible = false
