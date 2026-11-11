# Cyber Tower Defense (Godot 4)

> **Didaktisches Referenzprojekt für Vorlesung 18 (Case Study):** *Wegfindung, A\*, dynamisches Mazing & Sensorik*  
> **Hochschule Hamm-Lippstadt (HSHL)** | Prof. Dr. Robin Nunkesser  
> **Historisches Vorbild:** *Desktop Tower Defense* (HandyMan Studios / Preece, 2007)

[![Test & Export](https://github.com/RobinNunkesser/gd-godot-cyber-defense/actions/workflows/export.yml/badge.svg)](https://github.com/RobinNunkesser/gd-godot-cyber-defense/actions/workflows/export.yml)

Ein klassisches *Mazing Tower Defense* in Godot 4, das die informatischen Kernkonzepte hinter dynamischer A\*-Raster-Wegfindung (`AStarGrid2D`), Anti-Jailing-Validierung, dynamischem Re-Pathing von Einheiten und sensor-gestützter Turmdrehung mit Zielpriorisierung demonstriert.

---

## 🚀 Kernfeatures & Didaktischer Fokus

1. **A\*-Grid-Wegfindung & Heuristiken (`core/defense_grid_nav.gd`):**
   - Diskretes $24 \times 16$-Raster mit Manhattan-Heuristik (`AStarGrid2D.HEURISTIC_MANHATTAN`) und 4-Wege-Orthogonalbewegung (`DIAGONAL_MODE_NEVER`).
   - Ermittelt den kürzesten Weg für alle Creeps vom Spawn-Portal $(0, 8)$ zum Zielportal $(23, 8)$.

2. **Mazing-Invariante & Anti-Jailing-Schutz (`can_build_tower`):**
   - Im Gegensatz zu Schienen-TDs (Bloons, Kingdom Rush) ist das Feld offen: Der Spieler zwingt die Gegner durch Turmbau in ein Labyrinth.
   - Vor jeder Platzierung prüft eine spekulative A\*-Simulation:
     1. Bleibt der Hauptpfad von Spawn nach Ziel passierbar?
     2. Bleibt jeder bereits auf dem Spielfeld befindliche Creep in der Lage, das Ziel zu erreichen (*Anti-Jailing / No-Block-Garantie*)?
   - Verhindert illegales Einmauern der Gegner.

3. **Dynamisches Re-Pathing in Echtzeit:**
   - Sobald ein Turm gebaut oder verkauft wird, invalidieren alle aktiven Creeps ihren alten Pfad und berechnen ohne Stottern sofort die neue optimale Ausweichroute.

4. **Turm-Sensorik & Zielpriorisierung (`scripts/tower.gd`):**
   - Sensor-Reichweitenprüfung ($\mathcal{O}(1)$ Distanzquadrat).
   - Weiche Turmdrehung via `lerp_angle()` auf den Zielvektor.
   - Zielpriorisierung: Anvisieren des Creeps mit dem höchsten Fortschritt entlang der Wegpunkte (*Furthest Along Path*).
   - Drei spezialisierte Turmtypen:
     - **Gatling:** Schnellfeuer, Einzelziel.
     - **Kanone:** Hoher Direktschaden, schwere Plasma-Artillerie.
     - **EMP:** Verlangsamungs-Aura (*Slow Debuff*).

5. **Allokationsfreies Object Pooling (`core/object_pool.gd`):**
   - Strikte $\mathcal{O}(0)$ Allokationen während der Physik- und Wellenschleife für Creeps und Geschosse.

---

## 🎮 Steuerung & Tastenkürzel

| Taste / Eingabe | Aktion |
| :--- | :--- |
| **Linksklick auf Raster** | Ausgewählten Turm bauen / bestehenden Turm inspizieren |
| **`[1]`** | Gatling-Turm auswählen (15 Credits) |
| **`[2]`** | Kanonen-Turm auswählen (25 Credits) |
| **`[3]`** | EMP-Slow-Turm auswählen (30 Credits) |
| **`[Leertaste]`** | Nächste Welle sofort starten |
| **`[R]`** | Spiel neustarten |

---

## 🧪 Headless Tests ausführen

```bash
godot --headless -s test_gameplay.gd
```

