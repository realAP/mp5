# Logo-Werkzeug

Erzeugt die Dateien unter `docs/logo/` aus einer Formbeschreibung.

```
python3 tools/logo/gen.py docs/logo
```

Nur Standardbibliothek, keine Abhängigkeiten.

- `logos.py` – die Entwürfe als Listen von Flächen. Hier ändert man Farben,
  Füllstände oder Geometrie.
- `render.py` – winziger Rasterizer. Erzeugt aus derselben Beschreibung SVG
  **und** PNG, die beiden können also nicht auseinanderlaufen.
- `gen.py` – schreibt SVGs, PNGs, das Handout und die Einzelseiten.

Das PNG entsteht nicht, weil es gebraucht wird, sondern damit die Entwürfe
vor dem Ausliefern anzusehen sind – im Sandkasten gibt es keinen Browser und
keinen SVG-Rasterizer. Die Zwischenstände haben echte Fehler gezeigt: das
Magazin las sich als Leiter, die Patronen als Buntstifte, und bei der Kimme
war der Ausschnitt ein Sockel statt einer Kerbe.
