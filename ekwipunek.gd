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

var popup: PopupMenu
var menu_opcje: Array = []
var menu_dane: Dictionary = {}


func _ready() -> void:
	for i in range(1, 5):
		var slot: PanelContainer = $Panel/Margin/VBox/Slots.get_node("Slot%d" % i)
		slot_nodes.append(slot)
		slot.gui_input.connect(_on_slot_gui_input.bind(i - 1))
		_ustaw_myszke(slot, true)
	for i in range(1, 7):
		var slot: PanelContainer = $PlecakPanel/Margin/VBox/Grid.get_node("PSlot%d" % i)
		plecak_nodes.append(slot)
		slot.gui_input.connect(_on_plecak_gui_input.bind(i - 1))
		_ustaw_myszke(slot, true)
	popup = PopupMenu.new()
	add_child(popup)
	popup.id_pressed.connect(_on_popup_id)
	$Zakladki/ZakladkaEkwipunek.pressed.connect(_pokaz_zakladke.bind("ekwipunek"))
	$Zakladki/ZakladkaPlecak.pressed.connect(_pokaz_zakladke.bind("plecak"))
	$Zakladki/ZakladkaKowal.pressed.connect(_pokaz_zakladke.bind("kowal"))
	_pokaz_zakladke("ekwipunek")
	_odswiez()


func _ustaw_myszke(slot: PanelContainer, wlacz: bool) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_STOP if wlacz else Control.MOUSE_FILTER_IGNORE
	for child in slot.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE if wlacz else Control.MOUSE_FILTER_STOP
		for sub in child.get_children():
			sub.mouse_filter = Control.MOUSE_FILTER_IGNORE if wlacz else Control.MOUSE_FILTER_STOP


func _pokaz_zakladke(zakladka: String) -> void:
	$Panel.visible = zakladka == "ekwipunek"
	$PlecakPanel.visible = zakladka == "ekwipunek" or zakladka == "plecak"
	$KowalPanel.visible = zakladka == "kowal"
	if zakladka == "kowal":
		_aktualizuj_kowala()


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var nazwa: String = przedmioty[index]
		if nazwa == "":
			return
		_otworz_menu(["Zdejmij do plecaka", "Usun"], {"skad": "sloty", "index": index})


func _on_plecak_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var nazwa: String = plecak[index]
		if nazwa == "":
			return
		var opcje: Array = ["Usun"]
		if _czy_mikstura(nazwa):
			opcje.insert(0, "Uzyj")
		elif _czy_ulepszalny(nazwa):
			opcje.insert(0, "Zaloz")
			if _liczba_kamieni() > 0:
				opcje.insert(1, "Ulepsz u Kowala")
		_otworz_menu(opcje, {"skad": "plecak", "index": index})


func _otworz_menu(opcje: Array, dane: Dictionary) -> void:
	popup.clear()
	menu_opcje = opcje
	menu_dane = dane
	for i in range(opcje.size()):
		popup.add_item(opcje[i], i)
	popup.position = Vector2i(get_viewport().get_mouse_position())
	popup.popup()


func _on_popup_id(id: int) -> void:
	if id < 0 or id >= menu_opcje.size():
		return
	var akcja: String = menu_opcje[id]
	var skad: String = menu_dane.get("skad", "")
	var index: int = menu_dane.get("index", -1)
	if index < 0:
		return
	match akcja:
		"Zaloz":
			_zaloz_z_plecaka(index)
		"Uzyj":
			_uzyj_mikstury(index)
		"Zdejmij do plecaka":
			_odloz_do_plecaka(index)
		"Ulepsz u Kowala":
			_ulepsz_przedmiot(index)
		"Usun":
			_usun(skad, index)


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
		$KowalPanel/Margin/VBox/Lista.add_child(przycisk)
		kowal_przyciski.append(przycisk)
	if kowal_przyciski.size() == 0:
		var brak: Label = Label.new()
		brak.text = "(Brak przedmiotów do ulepszenia)"
		brak.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		$KowalPanel/Margin/VBox/Lista.add_child(brak)
		kowal_przyciski.append(brak)


func _on_kowal_przycisk(index: int) -> void:
	if _liczba_kamieni() <= 0:
		_komunikat_kowal("Brak Kamienia Kowalskiego!")
		return
	var nazwa: String = plecak[index]
	if nazwa == "":
		return
	_otworz_menu(["Ulepsz (1x Kamien Kowalski)"], {"skad": "kowal", "index": index})


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