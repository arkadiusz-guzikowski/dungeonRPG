# NOTATKI Z ROZMOWY — Dungeon RPG

> 📅 Data: 5.08.2026 (17:22-17:31)
> Projekt: `C:\Users\nogan\Documents\doungeon-rpg`
> Repozytorium: `https://github.com/arkadiusz-guzikowski/dungeonRPG.git` (branch `main`)

---

## 1. Co zostało zrobione (WCZEŚNIEJ w tej sesji)

### 🪨 Kamień Kowalski jako nowy drop (plik: `walka.gd`)
- Nowy, **NIEZALEŻNY** drop z potworów (domyślnie **35%** szansy, edytowalne w inspektorze jako `szansa_kamienia`)
- Losuje się osobno obok mikstury i przedmiotu — z jednego potwora może wypaść np. Miecz + Mikstura + Kamień

### ⚒️ Zakładka "Kowal" (pliki: `ekwipunek.tscn` + `ekwipunek.gd`)
- Nowe zakładki w UI: **Ekwipunek | Plecak | Kowal** (bez NPC na mapie)
- Panel Kowala pokazuje:
  - Ilość posiadanych Kamieni Kowalskich
  - Listę przedmiotów do ulepszenia (przyciski "⚒ Ulepsz: Miecz +2")
  - Komunikat wyniku ulepszenia
  - Zasady: **50% sukces / 25% nic / 25% zniszczenie**

### 🔨 Ulepszanie przedmiotów (w `ekwipunek.gd`)
- Wymaga **1 Kamienia Kowalskiego** (zużywany przy każdej próbie)
- **50%** — sukces: przedmiot dostaje `+1` (Miecz → Miecz +1 → Miecz +2...)
- **25%** — nic się nie dzieje, przedmiot zostaje
- **25%** — przedmiot psuje się i znika 💥
- Bonusy z ulepszonych przedmiotów działają w walce (`bonus_obrazenia()` / `redukcja_obrazen()` uwzględniają `_poziom(p)`)
- Kamień Kowalski w plecaku ma opcję **"Usuń"** (nie "Załóż" — to nie jest przedmiot do założenia)
- Szansa sukcesu i zniszczenia edytowalna w inspektorze:
  - `szansa_sukcesu` (domyślnie 0.5)
  - `szansa_zniszczenia` (domyślnie 0.25)

---

## 2. ⚠️ ZASADA (WAŻNA)

**NIE robić commitów ani pushów bez wyraźnej zgody użytkownika!**
- Zawsze zapytać przed jakąkolwiek operacją git
- Czekać na potwierdzenie

---

## 3. Status git

- Już wypchnięty na GitHub przed ustaleniem zasady:
  - Commit: `53c5532` "Dodano Kamien Kowalski jako drop i zakladke Kowal z ulepszaniem przedmiotow (50/25/25)"
  - Push: `7a9d938..53c5532  main -> main`
- Od tego momentu **NIE pushować dalej bez zgody**

---

## 4. Co zostało do zrobienia (NEXT STEPS)

- [ ] **Przetestować grę w Godocie** (nie udało się zweryfikować składni automatycznie — Godot nie był w PATH)
- [ ] Sprawdzić, czy zakładki działają poprawnie (przełączanie: Ekwipunek / Plecak / Kowal)
- [ ] Przetestować drop Kamienia Kowalskiego w walce
- [ ] Przetestować ulepszanie przedmiotów (sukces / nic / zniszczenie)
- [ ] Ewentualny commit push **PO uzyskaniu zgody użytkownika**

---

## 5. Ścieżki plików (dla szybkiego powrotu)

| Plik | Rola |
|------|------|
| `walka.gd` | Drop Kamienia Kowalskiego (szansa 35%) |
| `ekwipunek.gd` | Logika zakładek, kowal, ulepszanie 50/25/25 |
| `ekwipunek.tscn` | UI: zakładki + panel Kowala |
| `gracz.gd` | Sygnał `ekwipunek_zmieniony`, bonusy z poziomów |
| `doungeon_rpg.gd` | Główne połączenie potworów z walką |

---

## 6. Uwagi techniczne

- Ulepszone przedmioty zapisywane jako string z sufiksem: `"Miecz +1"`, `"Tarcza +3"` itd.
- Bazowa nazwa wyciągana w `_baza(nazwa)` (split po `" +"`), poziom w `_poziom(nazwa)`
- Nowe przedmioty NIE resetują się przy starcie (brak zapisu/ładowania gry jak dotąd — do rozważenia w przyszłości)