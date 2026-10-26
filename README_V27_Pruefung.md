# S.G.D. V27 – Nächster Schritt und gezielte Fehlerprüfung

## Änderungen

- Neue Karte „Mein nächster Schritt“ im vorhandenen Startseiten-Design.
- Eigene offene Aufträge werden priorisiert, Überarbeitungen zuerst, dann die früheste Frist. Nur bereits geladene Aufträge des aktuellen Kontos werden verwendet.
- Ohne offenen geladenen Auftrag: gespeicherte Karriereprüfung, Grundausbildung, nächste Rangprüfung oder weitere Missionen. Admins gelangen zur Einsatzzentrale.
- Texte aus Aufträgen werden vor der Anzeige maskiert.
- Verspätete Antworten beim Laden der Spielehalle, Rangdaten und weiterer V22-Bereiche werden bei einem Kontowechsel vor der Übernahme verworfen.
- Ein laufendes Action-Spiel wird beim Wechsel der angemeldeten Identität geschlossen; zugehöriger Nachrichten-Listener wird entfernt.

## Durchgeführte Prüfungen

28 automatisierte Prüfungen für Empfehlungsauswahl, Auftragsstatus, Zuordnung zum Konto, Fristenpriorität und verspätete Rangantworten. JavaScript-Syntax aller Skripte geprüft. Bestehende Dashboard-Zielhandler im Quelltext geprüft. Alle Dateien der V26 außer index.html sind bytegenau unverändert; neu ist dieser Bericht. Damit bleiben insbesondere Spiele, Escape-Räume und Logos erhalten.

## Noch offen

Diese Prüfung ist kein vollständiger Live-Test der Anwendung. In dieser Umgebung fehlt ein lauffähiger Testbrowser. Echte Anmeldung/Abmeldung, zwei Konten auf zwei Geräten, Chats und Nachrichtenversand, serverseitige Berechtigungen, Synchronisierung nach Gerätewechsel und echte iPhone-Ansichten müssen noch praktisch geprüft werden. Es wurden keine Testnachrichten verschickt und keine produktiven Datenbankdaten oder Berechtigungen geändert. Benachrichtigungen und Teamfunktionen sind bestehende Funktionen und wurden nicht als neue Funktionen ergänzt.

## Installation

ZIP entpacken und sämtliche enthaltenen Dateien wie bisher im Webverzeichnis ersetzen. Keine neue Datenbankeinrichtung erforderlich. Die zusätzliche Startseitenkarte verwendet bestehende Konten- und Karrierefunktionen. Hauptfarben und übriger Aufbau bleiben erhalten.
