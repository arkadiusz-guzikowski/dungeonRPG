extends CanvasLayer

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

const BAZA := {
	"Miecz": {"bonus_obrazenia": 1, "kolor": Color(0.75, 0.78, 0.85, 1)},
	"Tarcza": {"redukcja_obrazen": 1, "kolor": Color(0.35, 0.55, 0.85, 1)},
	"Mikstura zycia": {"leczenie": 50, "kolor": Color(0.9, 0.3, 0.3, 1)},
	"Kamien Kowalski": {"kolor": Color(0.6, 0.5, 0.4, 1)},
}

var slot_nodes: Array = []
var plecak_nodes: Array = []
var kowal_przyciski: Array = []

# ==== DRAG & DROP ====
const _PROG_DRAG: float = 10.0

var _ghost: Label
var _drag_aktywny: bool = false
var _drag_pressed: bool = false
var _drag_zrodlo: String = ""
var _drag_index: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
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
	$Zakladki/ZakladkaEkwipunek.pressed.connect(_pokaz_zakladke.bind("ekwipunek"))
	$Zakladki/ZakladkaPlecak.pressed.connect(_pokaz_zakladke.bind("plecak"))
	$Zakladki/ZakladkaKowal.pressed.connect(_pokaz_zakladke.bind("kowal"))
	_pokaz_zakladke("ekwipunek")
	_odswiez()


func _process(_delta: float) -> void:
	if _drag_aktywny and _ghost:
		_ghost.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)


func _pokaz_zakladke(zakladka: String) -> void:
	$Panel.visible = zakladka == "ekwipunek"
	$KowalPanel.visible = zakladka == "kowal"
	$PlecakPanel.visible = zakladka == "ekwipunek" or zakladka == "plecak" or zakladka == "kowal"
	if zakladka == "kowal":
		# Kowal na gorze, plecak pod spodem (aby moc przeciagac przedmioty do kowala)
		$KowalPanel.offset_top = 46
		$KowalPanel.offset_bottom = 276
		$PlecakPanel.offset_top = 286
		$PlecakPanel.offset_bottom = 436
		$KoszPanel.offset_top = 446
		$KoszPanel.offset_bottom = 496
	else:
		$PlecakPanel.offset_top = 176
		$PlecakPanel.offset_bottom = 326
		$KoszPanel.offset_top = 336
		$KoszPanel.offset_bottom = 386
	if zakladka == "kowal":
		_aktualizuj_kowala()


# ==== OBSLUGA MYSZY (drag & drop + klikniecie mikstury) ====
# Uzywamy _input() zamiast gui_input, aby przechwycic puszczenie przycisku
# nawet po przeciagnieciu poza slot (inaczej drag nie dzialalby poprawnie).

func _input(event: InputEvent) -> void:
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
		match cel["typ"]:
			"kosz":
				_usun(_drag_zrodlo, _drag_index)
			"kowal":
				if _drag_zrodlo == "plecak":
					_ulepsz_przez_drag()
			"slot":
				if _drag_zrodlo == "plecak":
					var nazwa := _nazwa_zrodla(_drag_zrodlo, _drag_index)
					if _czy_ulepszalny(nazwa):
						_zaloz_z_plecaka(_drag_index)
				elif _drag_zrodlo == "sloty":
					_zamien_sloty(_drag_index, cel.get("index", -1))
			"plecak":
				if _drag_zrodlo == "sloty":
					_odloz_do_plecaka_na(_drag_index, cel.get("index", -1))
				elif _drag_zrodlo == "plecak":
					_zamien_plecak(_drag_index, cel.get("index", -1))
	_drag_aktywny = false
	_drag_pressed = false
	_drag_zrodlo = ""
	_drag_index = -1


func _znajdz_cel() -> Dictionary:
	var mysz := get_viewport().get_mouse_position()
	if $KoszPanel.visible and $KoszPanel.get_global_rect().has_point(mysz):
		return {"typ": "kosz"}
	if $KowalPanel.visible and $KowalPanel.get_global_rect().has_point(mysz):
		return {"typ": "kowal"}
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
	else:
		przedmioty[index] = ""
	_odswiez()


func _odloz_do_plecaka(index: int) -> void:
	var nazwa: String = przedmioty[index]
	if nazwa == "":
		return
	for i in range(plecak.size()):
		if plecak[i] == "":
			plecak[i] = nazwa
			przedmioty[index] = ""
			_odswiez()
			return


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


# ==== KOWAL - ULEPSZANIE PRZEDMIOTOW ====

func _czy_ulepszalny(nazwa: String) -> bool:
	var b: String = _baza(nazwa)
	return b == "Miecz" or b == "Tarcza"


func _liczba_kamieni() -> int:
	var ile: int = 0
	for p in plecak:
		if p == "Kamien Kowalski":
			ile += 1
	return ile


func _zuzyj_kamien() -> void:
	for i in range(plecak.size()):
		if plecak[i] == "Kamien Kowalski":
			plecak[i] = ""
			return


func _aktualizuj_kowala() -> void:
	for b in kowal_przyciski:
		b.queue_free()
	kowal_przyciski.clear()
	var kamienie_label: Label = $KowalPanel/Margin/VBox/Kamienie
	kamienie_label.text = "Kamienie Kowalskie: %d" % _liczba_kamieni()
	for i in range(plecak.size()):
		var nazwa: String = plecak[i]
		if nazwa == "" or not _czy_ulepszalny(nazwa):
			continue
		var przycisk: Button = Button.new()
		przycisk.text = "⚒ Ulepsz: %s" % nazwa
		przycisk.custom_minimum_size = Vector2(0, 26)
		przycisk.pressed.connect(_on_kowal_przycisk.bind(i))
		$KowalPanel/Margin/VBox/Scroll/Lista.add_child(przycisk)
		kowal_przyciski.append(przycisk)
	if kowal_przyciski.size() == 0:
		var brak: Label = Label.new()
		brak.text = "(Brak przedmiotów do ulepszenia)"
		brak.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		$KowalPanel/Margin/VBox/Scroll/Lista.add_child(brak)
		kowal_przyciski.append(brak)


func _on_kowal_przycisk(index: int) -> void:
	# Klikniecie przycisku = od razu proba ulepszenia (bez menu potwierdzenia)
	_ulepsz_przedmiot(index)


func _ulepsz_przez_drag() -> void:
	if _drag_index < 0 or _drag_index >= plecak.size():
		return
	var nazwa: String = plecak[_drag_index]
	if nazwa == "" or not _czy_ulepszalny(nazwa):
		_komunikat_kowal("Kowal nie może ulepszyć tego przedmiotu.")
		return
	_ulepsz_przedmiot(_drag_index)


func _ulepsz_przedmiot(index: int) -> void:
	if index < 0 or index >= plecak.size():
		return
	var nazwa: String = plecak[index]
	if nazwa == "" or not _czy_ulepszalny(nazwa):
		return
	if _liczba_kamieni() <= 0:
		_komunikat_kowal("Brak Kamienia Kowalskiego!")
		return
	_zuzyj_kamien()
	var los: float = randf()
	if los < szansa_sukcesu:
		# 50% - sukces: przedmiot dostaje +1
		plecak[index] = "%s +%d" % [_baza(nazwa), _poziom(nazwa) + 1]
		_komunikat_kowal("✅ SUKCES! %s -> %s" % [nazwa, plecak[index]])
	elif los < szansa_sukcesu + szansa_zniszczenia:
		# 25% - przedmiot psuje sie i znika
		plecak[index] = ""
		_komunikat_kowal("💥 %s zniszczony!" % nazwa)
	else:
		# 25% - nic sie nie dzieje
		_komunikat_kowal("❌ Nieudane... %s zostaje." % nazwa)
	_odswiez()


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
	_aktualizuj_kowala()
	ekwipunek_zmieniony.emit()


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