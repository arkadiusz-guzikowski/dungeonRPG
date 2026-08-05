@tool
extends Node2D

signal ekwipunek_zmieniony

# Slot ekwipunku: 0 = Miecz, 1 = Tarcza, 2-3 = dodatkowe (aktualnie nieuzywane)
var przedmioty: Array[String] = ["Miecz", "Tarcza", "", ""]
# Plecak (przechowywane przedmioty) - 6 slotow
var plecak: Array[String] = ["", "", "", "", "", ""]

# ==== USTAWIENIA KOWALA (edytowalne w inspektorze) ====
@export_range(0.0, 1.0, 0.01)
var szansa_sukcesu: float = 0.5
@export_range(0.0, 1.0, 0.01)
var szansa_zniszczenia: float = 0.25

# ==== POZYCJA I ROZMIAR OKNA KOWALA (dla gry) ====
# Uwaga: wartosci te NIE nadpisuja pozycji w edytorze — tam okienka
# przesuwa sie myszka jak mape (bezposrednio w scenie).
@export var kowal_pozycja: Vector2 = Vector2(250, 24)
@export var kowal_rozmiar: Vector2 = Vector2(100, 100)

const BAZA := {
	"Miecz": {"bonus_obrazenia": 1, "kolor": Color(0.75, 0.78, 0.85, 1)},
	"Tarcza": {"redukcja_obrazen": 1, "kolor": Color(0.35, 0.55, 0.85, 1)},
	"Mikstura zycia": {"leczenie": 50, "kolor": Color(0.9, 0.3, 0.3, 1)},
	"Kamien Kowalski": {"kolor": Color(0.6, 0.5, 0.4, 1)},
}

var slot_nodes: Array = []
var plecak_nodes: Array = []

# ==== KOWAL - SLOTY ====
# Przedmiot/ kamien wlozony do kowala (zapis skad przyszedl, zeby wrocic tam po probie)
var _kowal_kamien: String = ""
var _kowal_kamien_src: String = ""
var _kowal_kamien_idx: int = -1
var _kowal_przedmiot: String = ""
var _kowal_przedmiot_src: String = ""
var _kowal_przedmiot_idx: int = -1

# ==== DRAG & DROP ====
const _PROG_DRAG: float = 10.0

var _ghost: Label
var _drag_aktywny: bool = false
var _drag_pressed: bool = false
var _drag_zrodlo: String = ""
var _drag_index: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# W edytorze NIE nadpisujemy pozycji okienek — pozwala to przeciagac je
	# myszka (jak mape). Wartosci exportow stosujemy dopiero w grze.
	if Engine.is_editor_hint():
		return
	_zastosuj_ustawienia_kowala()
	_ghost = Label.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 100
	_ghost.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_ghost.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_ghost.add_theme_constant_override("outline_size", 4)
	_ghost.add_theme_font_size_override("font_size", 13)
	_ghost.visible = false
	add_child(_ghost)
	for i in range(1, 5):
		var slot: PanelContainer = $Panel/Margin/VBox/Slots.get_node("Slot%d" % i)
		slot_nodes.append(slot)
	for i in range(1, 7):
		var slot: PanelContainer = $PlecakPanel/Margin/VBox/Grid.get_node("PSlot%d" % i)
		plecak_nodes.append(slot)
	$KowalPanel/Margin/VBox/UderzButton.pressed.connect(_uderz_mlotem)
	_odswiez()


func _zastosuj_ustawienia_kowala() -> void:
	var panel: Control = get_node_or_null("KowalPanel") as Control
	if panel == null:
		return
	panel.position = kowal_pozycja
	panel.size = kowal_rozmiar


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _drag_aktywny and _ghost:
		_ghost.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)


# ==== OBSLUGA MYSZY (drag & drop + klikniecie mikstury) ====
# Uzywamy _input() zamiast gui_input, aby przechwycic puszczenie przycisku
# nawet po przeciagnieciu poza slot (inaczej drag nie dzialalby poprawnie).

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var cel := _znajdz_slot_pod_mysza()
			if cel.has("typ"):
				var nazwa := _nazwa_zrodla(cel["typ"], cel["index"])
				if nazwa != "":
					_drag_pressed = true
					_drag_start_pos = get_viewport().get_mouse_position()
					_drag_zrodlo = cel["typ"]
					_drag_index = cel["index"]
		else:
			if _drag_aktywny:
				_zakoncz_drag()
			elif _drag_pressed and _drag_zrodlo == "plecak" and _drag_index >= 0 and _drag_index < plecak.size() and _czy_mikstura(plecak[_drag_index]):
				# Zwykle klikniecie na miksture = uzycie (bez przeciagania)
				_uzyj_mikstury(_drag_index)
			_drag_pressed = false
			_drag_zrodlo = ""
			_drag_index = -1
	elif event is InputEventMouseMotion and _drag_pressed and not _drag_aktywny:
		if get_viewport().get_mouse_position().distance_to(_drag_start_pos) >= _PROG_DRAG:
			_rozpocznij_drag()


func _znajdz_slot_pod_mysza() -> Dictionary:
	var mysz := get_viewport().get_mouse_position()
	if $KowalPanel.visible and $KowalPanel/Margin/VBox/KowalSloty/KamienBox/KamienSlot.get_global_rect().has_point(mysz):
		return {"typ": "kowal_kamien", "index": -1}
	if $KowalPanel.visible and $KowalPanel/Margin/VBox/KowalSloty/PrzedmiotBox/PrzedmiotSlot.get_global_rect().has_point(mysz):
		return {"typ": "kowal_przedmiot", "index": -1}
	for i in range(slot_nodes.size()):
		if slot_nodes[i].is_visible_in_tree() and slot_nodes[i].get_global_rect().has_point(mysz):
			return {"typ": "sloty", "index": i}
	for i in range(plecak_nodes.size()):
		if plecak_nodes[i].is_visible_in_tree() and plecak_nodes[i].get_global_rect().has_point(mysz):
			return {"typ": "plecak", "index": i}
	return {}


# ==== LOGIKA PRZECIAGANIA ====

func _rozpocznij_drag() -> void:
	var nazwa := _nazwa_zrodla(_drag_zrodlo, _drag_index)
	if nazwa == "":
		_drag_pressed = false
		return
	_drag_aktywny = true
	_ghost.text = nazwa
	_ghost.visible = true


func _zakoncz_drag() -> void:
	if _ghost:
		_ghost.visible = false
	if not _drag_aktywny:
		_drag_pressed = false
		_drag_zrodlo = ""
		_drag_index = -1
		return
	var cel := _znajdz_cel()
	if cel.has("typ"):
		var nazwa := _nazwa_zrodla(_drag_zrodlo, _drag_index)
		match cel["typ"]:
			"kosz":
				_usun(_drag_zrodlo, _drag_index)
			"kowal_kamien":
				if nazwa == "Kamien Kowalski":
					_wloz_kamien_do_kowala()
				else:
					_komunikat_kowal("Tu włóż Kamień Kowalski!")
			"kowal_przedmiot":
				if nazwa != "" and _czy_ulepszalny(nazwa):
					_wloz_przedmiot_do_kowala()
				else:
					_komunikat_kowal("Tu włóż Miecz lub Tarczę!")
			"slot":
				if _drag_zrodlo == "plecak":
					if _czy_ulepszalny(nazwa):
						_zaloz_z_plecaka(_drag_index)
				elif _drag_zrodlo == "sloty":
					_zamien_sloty(_drag_index, cel.get("index", -1))
				elif _drag_zrodlo == "kowal_przedmiot":
					_zaloz_z_kowala_na_slot(cel.get("index", -1))
				elif _drag_zrodlo == "kowal_kamien":
					_komunikat_kowal("Kamień włóż do plecaka lub sejfu.")
			"plecak":
				if _drag_zrodlo == "sloty":
					_odloz_do_plecaka_na(_drag_index, cel.get("index", -1))
				elif _drag_zrodlo == "plecak":
					_zamien_plecak(_drag_index, cel.get("index", -1))
				elif _drag_zrodlo == "kowal_kamien":
					_odloz_kamien_do_plecaka_na(cel.get("index", -1))
				elif _drag_zrodlo == "kowal_przedmiot":
					_odloz_z_kowala_do_plecaka_na(cel.get("index", -1))
	_drag_aktywny = false
	_drag_pressed = false
	_drag_zrodlo = ""
	_drag_index = -1


func _znajdz_cel() -> Dictionary:
	var mysz := get_viewport().get_mouse_position()
	if $KoszPanel.visible and $KoszPanel.get_global_rect().has_point(mysz):
		return {"typ": "kosz"}
	if $KowalPanel.visible and $KowalPanel/Margin/VBox/KowalSloty/KamienBox/KamienSlot.get_global_rect().has_point(mysz):
		return {"typ": "kowal_kamien"}
	if $KowalPanel.visible and $KowalPanel/Margin/VBox/KowalSloty/PrzedmiotBox/PrzedmiotSlot.get_global_rect().has_point(mysz):
		return {"typ": "kowal_przedmiot"}
	for i in range(slot_nodes.size()):
		if slot_nodes[i].is_visible_in_tree() and slot_nodes[i].get_global_rect().has_point(mysz):
			return {"typ": "slot", "index": i}
	for i in range(plecak_nodes.size()):
		if plecak_nodes[i].is_visible_in_tree() and plecak_nodes[i].get_global_rect().has_point(mysz):
			return {"typ": "plecak", "index": i}
	return {}


func _nazwa_zrodla(zrodlo: String, index: int) -> String:
	if zrodlo == "plecak" and index >= 0 and index < plecak.size():
		return plecak[index]
	if zrodlo == "sloty" and index >= 0 and index < przedmioty.size():
		return przedmioty[index]
	if zrodlo == "kowal_kamien":
		return _kowal_kamien
	if zrodlo == "kowal_przedmiot":
		return _kowal_przedmiot
	return ""


func _zamien_sloty(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= przedmioty.size() or b >= przedmioty.size() or a == b:
		return
	var tmp := przedmioty[a]
	przedmioty[a] = przedmioty[b]
	przedmioty[b] = tmp
	_odswiez()


func _zamien_plecak(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= plecak.size() or b >= plecak.size() or a == b:
		return
	var tmp := plecak[a]
	plecak[a] = plecak[b]
	plecak[b] = tmp
	_odswiez()


# ==== OPERACJE NA PRZEDMIOTACH ====

func _usun(skad: String, index: int) -> void:
	if skad == "plecak":
		plecak[index] = ""
	elif skad == "sloty":
		przedmioty[index] = ""
	elif skad == "kowal_kamien":
		_kowal_kamien = ""
		_kowal_kamien_src = ""
		_kowal_kamien_idx = -1
	elif skad == "kowal_przedmiot":
		_kowal_przedmiot = ""
		_kowal_przedmiot_src = ""
		_kowal_przedmiot_idx = -1
	_odswiez()


func _odloz_do_plecaka_na(index_slot: int, index_plecak: int) -> void:
	if index_slot < 0 or index_slot >= przedmioty.size() or index_plecak < 0 or index_plecak >= plecak.size():
		return
	var nazwa: String = przedmioty[index_slot]
	if nazwa == "":
		return
	if plecak[index_plecak] == "":
		plecak[index_plecak] = nazwa
		przedmioty[index_slot] = ""
	else:
		# Zamiana z przedmiotem w plecaku
		var tmp := plecak[index_plecak]
		plecak[index_plecak] = nazwa
		przedmioty[index_slot] = tmp
	_odswiez()


func _zaloz_z_plecaka(index: int) -> void:
	var nazwa: String = plecak[index]
	if nazwa == "":
		return
	var typ: String = _baza(nazwa)
	# Mozna zalozyc tylko JEDEN przedmiot danego rodzaju (miecz/tarcza)
	for i in range(przedmioty.size()):
		var obecny: String = przedmioty[i]
		if obecny == "":
			continue
		if _baza(obecny) == typ:
			# Zamiana: nowy na slot, stary wraca do plecaka
			przedmioty[i] = nazwa
			plecak[index] = obecny
			_odswiez()
			return
	# Nie ma jeszcze takiego typu - pierwszy wolny slot
	for i in range(przedmioty.size()):
		if przedmioty[i] == "":
			przedmioty[i] = nazwa
			plecak[index] = ""
			_odswiez()
			return


func _uzyj_mikstury(index: int) -> void:
	var gracz: Node2D = get_node_or_null("/root/Node2D/Gracz") as Node2D
	if gracz == null or not gracz.has_method("lecz"):
		return
	gracz.lecz(BAZA["Mikstura zycia"]["leczenie"])
	plecak[index] = ""
	_odswiez()


# ==== KOWAL - WKLADANIE I ULEPSZANIE ====

func _czy_ulepszalny(nazwa: String) -> bool:
	var b: String = _baza(nazwa)
	return b == "Miecz" or b == "Tarcza"


func _wloz_kamien_do_kowala() -> void:
	if _drag_zrodlo == "kowal_kamien":
		return
	var nazwa := _nazwa_zrodla(_drag_zrodlo, _drag_index)
	if nazwa == "":
		return
	_usun(_drag_zrodlo, _drag_index)
	if _kowal_kamien != "":
		_zwroc_kamien()
	_kowal_kamien = nazwa
	_kowal_kamien_src = _drag_zrodlo
	_kowal_kamien_idx = _drag_index
	_odswiez()


func _wloz_przedmiot_do_kowala() -> void:
	if _drag_zrodlo == "kowal_przedmiot":
		return
	var nazwa := _nazwa_zrodla(_drag_zrodlo, _drag_index)
	if nazwa == "":
		return
	_usun(_drag_zrodlo, _drag_index)
	if _kowal_przedmiot != "":
		_zwroc_przedmiot()
	_kowal_przedmiot = nazwa
	_kowal_przedmiot_src = _drag_zrodlo
	_kowal_przedmiot_idx = _drag_index
	_odswiez()


func _zwroc_kamien() -> void:
	var idx := _wolny_slot_plecaka()
	if idx >= 0:
		plecak[idx] = _kowal_kamien
	_kowal_kamien = ""
	_kowal_kamien_src = ""
	_kowal_kamien_idx = -1


func _zwroc_przedmiot() -> void:
	var nazwa := _kowal_przedmiot
	var src := _kowal_przedmiot_src
	var idx := _kowal_przedmiot_idx
	_kowal_przedmiot = ""
	_kowal_przedmiot_src = ""
	_kowal_przedmiot_idx = -1
	_daj_na(src, idx, nazwa)


func _daj_na(src: String, idx: int, nazwa: String) -> void:
	if src == "sloty" and idx >= 0 and idx < przedmioty.size() and przedmioty[idx] == "":
		przedmioty[idx] = nazwa
		return
	if src == "plecak" and idx >= 0 and idx < plecak.size() and plecak[idx] == "":
		plecak[idx] = nazwa
		return
	var wolny := _wolny_slot_plecaka()
	if wolny >= 0:
		plecak[wolny] = nazwa


func _odloz_kamien_do_plecaka_na(index_plecak: int) -> void:
	var idx := index_plecak
	if idx < 0 or idx >= plecak.size() or plecak[idx] != "":
		idx = _wolny_slot_plecaka()
	if idx < 0:
		_komunikat_kowal("Brak miejsca w plecaku!")
		return
	plecak[idx] = _kowal_kamien
	_kowal_kamien = ""
	_kowal_kamien_src = ""
	_kowal_kamien_idx = -1
	_odswiez()


func _odloz_z_kowala_do_plecaka_na(index_plecak: int) -> void:
	var nazwa := _kowal_przedmiot
	var idx := index_plecak
	if idx < 0 or idx >= plecak.size() or plecak[idx] != "":
		idx = _wolny_slot_plecaka()
	if idx < 0:
		_komunikat_kowal("Brak miejsca w plecaku!")
		return
	plecak[idx] = nazwa
	_kowal_przedmiot = ""
	_kowal_przedmiot_src = ""
	_kowal_przedmiot_idx = -1
	_odswiez()


func _zaloz_z_kowala_na_slot(index_slot: int) -> void:
	var nazwa := _kowal_przedmiot
	if nazwa == "":
		return
	var typ: String = _baza(nazwa)
	# Zamiana z zalożonym przedmiotem tego samego typu
	for i in range(przedmioty.size()):
		var obecny: String = przedmioty[i]
		if obecny == "":
			continue
		if _baza(obecny) == typ:
			przedmioty[i] = nazwa
			_kowal_przedmiot = obecny
			_kowal_przedmiot_src = "kowal_przedmiot"
			_kowal_przedmiot_idx = -1
			_odswiez()
			return
	if index_slot >= 0 and index_slot < przedmioty.size() and przedmioty[index_slot] == "":
		przedmioty[index_slot] = nazwa
		_kowal_przedmiot = ""
		_kowal_przedmiot_src = ""
		_kowal_przedmiot_idx = -1
		_odswiez()


func _uderz_mlotem() -> void:
	if _kowal_kamien == "":
		_komunikat_kowal("Włóż Kamień Kowalski!")
		return
	if _kowal_przedmiot == "":
		_komunikat_kowal("Włóż Miecz lub Tarczę!")
		return
	# Kamien zostaje zuzyty (przedmiot czeka na wynik animacji)
	_kowal_kamien = ""
	_kowal_kamien_src = ""
	_kowal_kamien_idx = -1
	var nazwa := _kowal_przedmiot
	# Wynik losujemy NAJPIERW (dokładnie te same szanse co zawsze) —
	# wskazówka jest tylko WIZUALIZACJĄ tego wyniku.
	var los: float = randf()
	var wynik: String
	if los < szansa_sukcesu:
		wynik = "sukces"
	elif los < szansa_sukcesu + szansa_zniszczenia:
		wynik = "zniszczenie"
	else:
		wynik = "nieudane"
	# Blokada przycisku na czas animacji
	$KowalPanel/Margin/VBox/UderzButton.disabled = true
	_komunikat_kowal("")
	_odswiez()
	# Animacja wskazówki — kręci się i zatrzymuje na strefie wyniku
	var wskaznik: Node = $KowalPanel/Margin/VBox/Wskaznik
	if wskaznik != null and wskaznik.has_method("animuj_do_wyniku"):
		await wskaznik.animuj_do_wyniku(wynik)
	else:
		await get_tree().create_timer(1.7).timeout
	# Po zatrzymaniu wskazówki wykonujemy efekt
	match wynik:
		"sukces":
			var nowa: String = "%s +%d" % [_baza(nazwa), _poziom(nazwa) + 1]
			_komunikat_kowal("✅ SUKCES! %s -> %s" % [nazwa, nowa])
			_daj_z_kowala(nowa)
		"zniszczenie":
			_komunikat_kowal("💥 %s zniszczony!" % nazwa)
			_kowal_przedmiot = ""
			_kowal_przedmiot_src = ""
			_kowal_przedmiot_idx = -1
		"nieudane":
			_komunikat_kowal("❌ Nieudane... %s zostaje." % nazwa)
			_daj_z_kowala(nazwa)
	_odswiez()
	$KowalPanel/Margin/VBox/UderzButton.disabled = false


func _daj_z_kowala(nazwa: String) -> void:
	var src := _kowal_przedmiot_src
	var idx := _kowal_przedmiot_idx
	_kowal_przedmiot = ""
	_kowal_przedmiot_src = ""
	_kowal_przedmiot_idx = -1
	_daj_na(src, idx, nazwa)


func _liczba_kamieni() -> int:
	var ile: int = 0
	for p in plecak:
		if p == "Kamien Kowalski":
			ile += 1
	if _kowal_kamien == "Kamien Kowalski":
		ile += 1
	return ile


func _komunikat_kowal(tekst: String) -> void:
	$KowalPanel/Margin/VBox/Wynik.text = tekst


func _czy_mikstura(nazwa: String) -> bool:
	return _baza(nazwa) == "Mikstura zycia"


func _baza(nazwa: String) -> String:
	return nazwa.split(" +")[0]


func _poziom(nazwa: String) -> int:
	if nazwa.contains(" +"):
		return int(nazwa.split(" +")[1])
	return 0


func _kolor(nazwa: String) -> Color:
	return BAZA[_baza(nazwa)]["kolor"]


func _wolny_slot_plecaka() -> int:
	for i in range(plecak.size()):
		if plecak[i] == "":
			return i
	return -1


func bonus_obrazenia() -> int:
	var suma: int = 0
	for p in przedmioty:
		if p == "":
			continue
		var b: String = _baza(p)
		if BAZA.has(b) and BAZA[b].has("bonus_obrazenia"):
			suma += int(BAZA[b]["bonus_obrazenia"]) + _poziom(p)
	return suma


func redukcja_obrazen() -> int:
	var suma: int = 0
	for p in przedmioty:
		if p == "":
			continue
		var b: String = _baza(p)
		if BAZA.has(b) and BAZA[b].has("redukcja_obrazen"):
			suma += int(BAZA[b]["redukcja_obrazen"]) + _poziom(p)
	return suma


func dodaj_przedmiot(nazwa: String) -> void:
	if nazwa == "" or not BAZA.has(_baza(nazwa)):
		return
	for i in range(plecak.size()):
		if plecak[i] == "":
			plecak[i] = nazwa
			_odswiez()
			return


func _odswiez() -> void:
	_odswiez_sloty(slot_nodes, przedmioty)
	_odswiez_sloty(plecak_nodes, plecak)
	_odswiez_kowal()
	ekwipunek_zmieniony.emit()


func _odswiez_kowal() -> void:
	var kamienie_label: Label = $KowalPanel/Margin/VBox/Kamienie
	kamienie_label.text = "Kamienie Kowalskie: %d" % _liczba_kamieni()
	_odswiez_slot_single($KowalPanel/Margin/VBox/KowalSloty/KamienBox/KamienSlot, _kowal_kamien)
	_odswiez_slot_single($KowalPanel/Margin/VBox/KowalSloty/PrzedmiotBox/PrzedmiotSlot, _kowal_przedmiot)


func _odswiez_slot_single(slot: PanelContainer, nazwa: String) -> void:
	var nazwa_label: Label = slot.get_node("VBox/Nazwa")
	var icona: ColorRect = slot.get_node("VBox/Icona")
	if nazwa != "":
		nazwa_label.text = nazwa
		icona.color = _kolor(nazwa)
	else:
		nazwa_label.text = ""
		icona.color = Color(0.2, 0.2, 0.2, 1)


func _odswiez_sloty(sloty: Array, lista: Array) -> void:
	for i in range(sloty.size()):
		var slot: PanelContainer = sloty[i]
		var nazwa_label: Label = slot.get_node("VBox/Nazwa")
		var icona: ColorRect = slot.get_node("VBox/Icona")
		var nazwa: String = lista[i]
		if nazwa != "":
			nazwa_label.text = nazwa
			icona.color = _kolor(nazwa)
		else:
			nazwa_label.text = ""
			icona.color = Color(0.2, 0.2, 0.2, 1)
