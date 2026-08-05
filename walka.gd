extends CanvasLayer

signal walka_zakonczona

@export_range(0.0, 5.0, 0.05)
var czas_miedzy_turami: float = 0.45
@export_range(0.0, 5.0, 0.05)
var czas_po_ataku: float = 0.35
@export_range(0.0, 5.0, 0.05)
var czas_po_wygranej: float = 1.0

var gracz: Node2D
var potwor: Polygon2D
var potwor_nazwa: String = ""
var potwor_hp: int = 0
var potwor_atak_min: int = 1
var potwor_atak_max: int = 2
var walka_trwa: bool = false
var gracz_max_hp: int = 1
var potwor_max_hp: int = 1

@onready var tlo: ColorRect = $Tlo
@onready var panel: PanelContainer = $Panel
@onready var info_label: Label = $Panel/Margin/VBox/Info
@onready var gracz_hp_label: Label = $Panel/Margin/VBox/GraczHp
@onready var gracz_hp_bar: ProgressBar = $Panel/Margin/VBox/GraczHpBar
@onready var potwor_hp_label: Label = $Panel/Margin/VBox/PotworHp
@onready var potwor_hp_bar: ProgressBar = $Panel/Margin/VBox/PotworHpBar
@onready var log_label: RichTextLabel = $Panel/Margin/VBox/Log
@onready var drop_panel: PanelContainer = $DropPanel
@onready var drop_button: Button = $DropPanel/Margin/VBox/DropButton


func _ready() -> void:
	_ukryj()
	drop_panel.visible = false
	drop_button.pressed.connect(_zamknij_drop)


func _pokaz() -> void:
	tlo.visible = true
	panel.visible = true


func _ukryj() -> void:
	tlo.visible = false
	panel.visible = false


func start_walka(potwor_p: Polygon2D) -> void:
	if walka_trwa:
		return
	potwor = potwor_p
	gracz = get_node_or_null("/root/Node2D/Gracz") as Node2D
	var staty := _statystyki()
	potwor_nazwa = staty["nazwa"]
	potwor_hp = staty["hp"]
	potwor_max_hp = potwor_hp
	potwor_atak_min = staty["obrazenia_min"]
	potwor_atak_max = staty["obrazenia_max"]
	walka_trwa = true
	gracz_max_hp = gracz.hp_max
	gracz_hp_bar.max_value = gracz_max_hp
	gracz_hp_bar.value = gracz.hp
	potwor_hp_bar.max_value = potwor_max_hp
	potwor_hp_bar.value = potwor_max_hp
	info_label.text = "Gracz vs %s" % potwor_nazwa
	log_label.text = ""
	_dodaj_log("===== WALKA! %s vs %s =====" % ["Gracz", potwor_nazwa])
	_aktualizuj_hp()
	_pokaz()
	_petla_walki()


func _statystyki() -> Dictionary:
	var potwory := get_node_or_null("/root/Node2D/Potwory")
	if potwory and potwor:
		var staty = potwory.STATYSTYKI.get(potwor.color)
		if staty:
			return staty
	return {"nazwa": "Champion", "hp": 30, "obrazenia_min": 2, "obrazenia_max": 4}


func _aktualizuj_hp() -> void:
	if gracz:
		gracz_hp_label.text = "Gracz HP: %d" % gracz.hp
		gracz_hp_bar.value = gracz.hp
	potwor_hp_label.text = "%s HP: %d" % [potwor_nazwa, potwor_hp]
	potwor_hp_bar.value = potwor_hp


func _petla_walki() -> void:
	while walka_trwa:
		await _tura_gracza()
		if not walka_trwa:
			return
		await get_tree().create_timer(czas_miedzy_turami).timeout
		await _tura_potwora()
		if not walka_trwa:
			return
		await get_tree().create_timer(czas_miedzy_turami).timeout


func _tura_gracza() -> void:
	var dmg: int = gracz.atakuj()
	potwor_hp -= dmg
	_dodaj_log("⚔  Gracz trafia %s za %d HP." % [potwor_nazwa, dmg])
	_aktualizuj_hp()
	if potwor_hp <= 0:
		_wygrana()
		return
	await get_tree().create_timer(czas_po_ataku).timeout


func _tura_potwora() -> void:
	var dmg: int = randi_range(potwor_atak_min, potwor_atak_max)
	gracz.otrzymaj_obrazenia(dmg)
	_dodaj_log("👹 %s atakuje gracza za %d HP." % [potwor_nazwa, dmg])
	_aktualizuj_hp()
	if gracz.hp <= 0:
		_przegrana()
		return
	await get_tree().create_timer(czas_po_ataku).timeout


func _wygrana() -> void:
	walka_trwa = false
	_dodaj_log("🏆 Pokonałeś %s!" % potwor_nazwa)
	if potwor:
		potwor.visible = false
	await get_tree().create_timer(czas_po_wygranej).timeout
	drop_panel.visible = true


func _przegrana() -> void:
	walka_trwa = false
	_dodaj_log("💀 Zostałeś pokonany przez %s..." % potwor_nazwa)
	await get_tree().create_timer(czas_po_wygranej).timeout
	_ukryj()
	walka_zakonczona.emit()


func _zamknij_drop() -> void:
	drop_panel.visible = false
	_ukryj()
	walka_zakonczona.emit()


func _dodaj_log(tekst: String) -> void:
	log_label.append_text(tekst + "\n")