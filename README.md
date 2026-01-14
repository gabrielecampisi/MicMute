# MicMute 🎙️

**MicMute** è un'utility leggera e moderna per macOS progettata da **Gabriele Campisi** per gestire il silenziamento del microfono direttamente dalla barra dei menu o tramite scorciatoie da tastiera globali.

L'applicazione è scritta in Swift e utilizza le API di basso livello di Core Audio per garantire la massima compatibilità con tutti i dispositivi di input (USB, Bluetooth, integrati).

## ✨ Caratteristiche

- **Toggle Rapido**: Clicca con il tasto sinistro sull'icona della barra dei menu per mutare/smutare istantaneamente.
- **Icona Intelligente**: L'icona diventa **rossa** quando sei mutato e si adatta al tema di sistema (bianco/nero) quando il microfono è attivo.
- **Scorciatoia Globale**: Usa `Cmd + Shift + M` per mutare il microfono da qualsiasi applicazione.
- **Feedback Visivo (OSD)**: Visualizza un indicatore a centro schermo (On-Screen Display) ogni volta che lo stato cambia.
- **Gestione Multi-Dispositivo**: Seleziona facilmente quale microfono controllare dal menu contestuale (Click destro).
- **Avvio al Login**: Opzione integrata per avviare l'app automaticamente all'accensione del Mac.

## 🚀 Installazione & Compilazione

### Prerequisiti
- macOS 13.0 o superiore.
- Xcode 15.0+ (per la compilazione).
- [HotKey library](https://github.com/soffes/HotKey) (dipendenza necessaria).

### Compilazione manuale
1. Clona il repository.
2. Apri `MicMute.xcodeproj` in Xcode.
3. Assicurati che le icone `mic_on` e `mic_off` siano presenti in `Assets.xcassets`.
4. Seleziona il target **MicMute** e premi `Cmd + R` per compilare ed eseguire.

## 🛠 Architettura Tecnica

Sviluppata da Gabriele Campisi, l'app si basa su un'architettura reattiva agli eventi hardware:
- **Core Audio Listeners**: Invece di interrogare costantemente il sistema, l'app registra dei listener che vengono attivati dal kernel solo quando lo stato cambia.
- **SMAppService**: Utilizza il framework moderno di Apple per la persistenza al login.
- **Event Interception**: Gestione differenziata dei click del mouse (Left/Right click) per un'esperienza utente ottimizzata.



## 📜 Licenza

Copyright (c) 2025 Gabriele Campisi.
Questo progetto è distribuito sotto la licenza **GNU GPL v3**. Consulta il file `LICENSE` per maggiori dettagli.

---
**Credits:** Sviluppato con ❤️ da **Gabriele Campisi**. 
Se questo strumento ti è utile, considera una piccola donazione tramite il link nel menu dell'app.
