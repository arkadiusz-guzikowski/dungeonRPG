@tool
extends Polygon2D

@export var rozmiar_mapy: Vector2 = Vector2(900, 600):
	set(value):
		rozmiar_mapy = value
		_aktualizuj()
@export var kolor_mapy: Color = Color(1, 1, 1, 1):
	set(value):
		kolor_mapy = value
		_aktualizuj()


func _ready() -> void:
	_aktualizuj()


func _aktualizuj() -> void:
	polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(rozmiar_mapy.x, 0),
		Vector2(rozmiar_mapy.x, rozmiar_mapy.y),
		Vector2(0, rozmiar_mapy.y)
	])
	color = kolor_mapy