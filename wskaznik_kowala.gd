extends Control
# ============================================================
#  WSKAŹNIK KOWALA — koło wyników po "Uderz młotem"
#  Wyłącznie WIZUALIZACJA: wynik jest losowany wcześniej w
#  ekwipunek.gd (te same szanse co zawsze), a wskazówka
#  zatrzymuje się na strefie odpowiadającej temu wynikowi.
#    🟢 zielona = SUKCES (przedmiot ulepszony)
#    ⚪ szara   = NIEUDANE (przedmiot zostaje)
#    🔴 czerwona = ZNISZCZENIE (przedmiot przepada)
# ============================================================

# Rozmiar stref w stopniach (zgodnie z ruchem wskazówek od góry):
# zielona -> szara -> czerwona. Suma powinna wynosić 360.
@export_range(1, 360, 1) var zielone_stopnie: int = 180
@export_range(1, 360, 1) var szare_stopnie: int = 90
@export_range(1, 360, 1) var czerwone_stopnie: int = 90

# Kąt wskazówki (radiany, 0 = prawo, dodatni = zgodnie z ruchem wskazówek)
var wskazowka_kat: float = -PI / 2.0:
	set(value):
		wskazowka_kat = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var srodek := size / 2.0
	var promien: float = min(size.x, size.y) / 2.0 - 4.0
	if promien <= 0.0:
		return
	# Ciemna tarcza pod kołem
	draw_circle(srodek, promien + 4.0, Color(0, 0, 0, 0.85))
	# Strefy (zgodnie z ruchem wskazówek, od góry: zielona -> szara -> czerwona)
	var katy := [float(zielone_stopnie), float(szare_stopnie), float(czerwone_stopnie)]
	var kolory := [
		Color(0.2, 0.75, 0.3, 1.0),
		Color(0.55, 0.55, 0.58, 1.0),
		Color(0.85, 0.2, 0.2, 1.0),
	]
	var a: float = -PI / 2.0
	for i in range(3):
		_draw_wycinek(srodek, promien, a, a + deg_to_rad(katy[i]), kolory[i])
		a += deg_to_rad(katy[i])
	# Obrys koła
	draw_arc(srodek, promien, 0.0, TAU, 64, Color(0, 0, 0, 0.9), 3.0)
	# Separatory między strefami
	a = -PI / 2.0
	for i in range(3):
		draw_line(srodek, srodek + Vector2(cos(a), sin(a)) * promien, Color(0, 0, 0, 0.9), 2.0)
		a += deg_to_rad(katy[i])
	# Wskazówka (jak wskazówka zegara) — zaczyna się od środka, tylko lekko
	# wystaje za niego, zwęża się do cienkiego ostrego czubka przy krawędzi
	var kier := Vector2(cos(wskazowka_kat), sin(wskazowka_kat))
	var prostopadla := Vector2(-kier.y, kier.x)
	var czubek := srodek + kier * (promien - 8.0)  # ostry, cienki czubek
	var podstawa := srodek - kier * (promien * 0.04)  # podstawa tuż za środkiem
	var polowa_szer := promien * 0.10
	draw_colored_polygon(
		PackedVector2Array([
			czubek,
			podstawa + prostopadla * polowa_szer,
			podstawa - prostopadla * polowa_szer,
		]),
		Color(1.0, 0.55, 0.15, 1.0)
	)
	draw_line(srodek, czubek, Color(0.9, 0.45, 0.1, 1.0), 2.0)
	# Środek koła
	draw_circle(srodek, promien * 0.12, Color(0.12, 0.12, 0.16, 1.0))
	draw_circle(srodek, promien * 0.07, Color(1.0, 0.85, 0.2, 1.0))


func _draw_wycinek(srodek: Vector2, promien: float, kat_pocz: float, kat_kon: float, kolor: Color) -> void:
	var punkty := PackedVector2Array()
	punkty.append(srodek)
	var kroki: int = 48
	for i in range(kroki + 1):
		var t: float = float(i) / float(kroki)
		var kat: float = lerp(kat_pocz, kat_kon, t)
		punkty.append(srodek + Vector2(cos(kat), sin(kat)) * promien)
	draw_colored_polygon(punkty, kolor)


func resetuj() -> void:
	wskazowka_kat = -PI / 2.0


# Losuje kąt (w radianach, 0..TAU od góry zgodnie z ruchem wskazówek)
# wewnątrz strefy odpowiadającej wynikowi.
func _losuj_kat_wzgledny(wynik: String) -> float:
	var g: float = deg_to_rad(float(zielone_stopnie))
	var s: float = deg_to_rad(float(szare_stopnie))
	var r: float = TAU - g - s
	var pocz: float
	var rozmiar: float
	match wynik:
		"sukces":
			pocz = 0.0
			rozmiar = g
		"nieudane":
			pocz = g
			rozmiar = s
		_:
			pocz = g + s
			rozmiar = r
	return pocz + randf() * rozmiar


# Animuje wskazówkę: obrót zgodnie z ruchem wskazówek (3-5 okrążeń),
# płynne hamowanie i zatrzymanie w strefie wyniku. Zwraca po zatrzymaniu.
func animuj_do_wyniku(wynik: String) -> void:
	var kat_wzgledny := _losuj_kat_wzgledny(wynik)
	var cel_abs: float = -PI / 2.0 + kat_wzgledny
	# Reset do pozycji startowej (góra tarczy) przed każdym losowaniem,
	# aby każde uderzenie wyglądało identycznie jak pierwsze.
	wskazowka_kat = -PI / 2.0
	var obecny: float = wskazowka_kat
	var obroty: float = float(randi_range(3, 5)) * TAU
	var do_celu: float = fposmod(cel_abs - obecny, TAU)
	var docelowy: float = obecny + obroty + do_celu
	var tween := create_tween()
	tween.tween_property(self, "wskazowka_kat", docelowy, 1.7) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished
