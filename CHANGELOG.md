# Changelog

## 0.1.0

Erste Veröffentlichung.

- Mana-Regeneration pro 5 Sekunden in beiden Stufen (`12 / 47`), gemessen
  statt nachgerechnet, dazu die 5-Sekunden-Regel als Balken mit Restzeit.
- Zauber-Leiste: bis zu fünf Zauber mit der Zahl, wie oft das Mana noch
  reicht – Zauberzeit und Regeneration während des Zaubers eingerechnet.
- Frei platzierbar und skalierbar, Einstellungen pro Charakter, Optionen
  im Spiel unter *Interface ▸ AddOns ▸ MP5*.
- Auskunft über sich selbst: `/mp5 why`, `/mp5 probe`, `/mp5 errors`.

### Beta in dieser Version

**Mana mitrechnen, wenn der Client es nicht herausgibt.** Manche Clients
geben Addons den aktuellen Manawert nicht heraus. MP5 führt dann selbst
Buch: Kosten der gewirkten Zauber abziehen, Regeneration dazu, dabei das
Mana aus Segen der Weisheit und Manaquelle mitzählen und im Takt der
Mana-Ereignisse gutschreiben. Eine Tilde (`~847`) heißt „mindestens so
viel".

Dieser Teil wird noch entwickelt und getestet. Er kann danebenliegen; der
Knopf in der Ecke der Anzeige („mein Mana ist jetzt voll") setzt ihn
zurecht, `/mp5 debug` zeigt, wie er auf seine Zahl kommt. Abschaltbar mit
`/mp5 estimate off`.
