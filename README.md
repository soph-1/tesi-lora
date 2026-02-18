# Reti Wireless Basate su Tecnologia LoRa
### Una analisi del funzionamento e dei protocolli di sicurezza con validazione tramite prototipo su rete Meshtastic.

## 📌 Overview

Progetto di tesi sulla creazione di una rete di sensori decentralizzata basata su LoRa e Meshtastic per contesti in cui la connettività tradizionale è assente o limitata.

L'applicazione include:

- Raccolta dati ambientali dai sensori BME280 (temperatura, umidità, pressione)
- Trasmissione dei dati attraverso una rete mesh decentralizzata via LoRa
- Visualizzazione in tempo reale dei dati e della posizione dei nodi tramite l'app MeshView
- Analisi delle prestazioni della rete: stabilità, RSSI, SNR, corretto instradamento dei pacchetti

## 🛠 Tecnologie utilizzate

- **Meshtastic**: Framework per reti mesh LoRa decentralizzate
- **Flutter/Dart**: Sviluppo dell'app mobile MeshView
- **Heltec Wireless Tracker v1.2**: ESP32 + LoRa SX1276 + GPS
- **BME280**: Sensore ambientale (temperatura, umidità, pressione)
- **Bluetooth Low Energy (BLE)**: Connessione tra app e nodi
- **Protobuf**: Decodifica dei pacchetti telemetrici

## 🎯 Obiettivi del progetto

- Progettare e implementare una rete mesh decentralizzata off-grid
- Integrare sensori ambientali e GPS sui nodi Heltec
- Sviluppare un'app mobile per visualizzazione e monitoraggio della rete
- Analizzare le prestazioni: copertura, RSSI, SNR e instradamento
- Fornire una soluzione scalabile per aree senza connettività tradizionale

## 📂 Struttura della Repository
```
tesi-lora/
│
├── docs/                   → Tesi
├── meshview_app/           → Applicazione mobile MeshView
│   ├── android/            → Progetto Android nativo
│   ├── lib/                → Codice sorgente Flutter/Dart
│   ├── assets/             → Immagini, icone, grafici e risorse
│   ├── pubspec.yaml        → Dipendenze Flutter
│   ├── pubspec.lock        → Lock file delle dipendenze
│   └── .gitignore
└── README.md
```

## 🚀 Come installare e avviare MeshView

### Prerequisiti

- **Flutter SDK** installato ([flutter.dev](https://flutter.dev))
- **Dispositivo mobile** (Android/iOS) o emulatore per test
- **Nodi Heltec Wireless Tracker v1.2** con firmware Meshtastic aggiornato
- **Bluetooth abilitato** sul dispositivo mobile

### Step-by-step

1. **Clona il repository**:
```bash
git clone https://github.com/tuo-username/lora-meshtastic-mesh.git
cd lora-meshtastic-mesh
```

2. **Accedi alla cartella dell'app**:
```bash
cd meshview_app
```

3. **Installa le dipendenze Flutter**:
```bash
flutter pub get
```

4. **Avvia l'app su dispositivo/emulatore**:
```bash
flutter run
```

L'app si connette automaticamente via BLE a un nodo Heltec nelle vicinanze e inizia a ricevere i pacchetti telemetrici di tutta la rete mesh.

## 📖 MeshView – App Principale

MeshView è l'applicazione mobile per interagire con la rete Meshtastic:

### Funzionalità

- **Connessione BLE**: Collegamento automatico a un nodo Heltec tramite Bluetooth Low Energy
- **Decodifica Protobuf**: Interpretazione automatica dei pacchetti telemetrici ricevuti
- **Viste disponibili**:
  - **Map**: Posizione GPS dei nodi e dati ambientali in tempo reale
  - **Heat Map**: Distribuzione spaziale delle misure ambientali
  - **Log**: Registrazione periodica dei dati, filtrabile per mese

### Interfaccia

L'app fornisce una visualizzazione intuitiva della rete con:
- Mappa interattiva con posizioni dei nodi
- Grafici e heatmap per analisi dati
- Cronologia completa dei messaggi ricevuti
- Filtri e ricerca per navigare i dati

### Modalità Demo

Se non hai nodi fisici disponibili, puoi testare l'app in **modalità demo**:
- L'app simula più nodi con dati artificiali
- Visualizza la rete mesh e i sensori ambientali in tempo reale
- Perfetto per familiarizzarsi con l'interfaccia

## 📊 Risultati dei Test

- **Comunicazione LoRa**: Stabile tra nodi con RSSI ~ -26 dBm, SNR ~ 8 dB
- **Telemetria**: Coerente tra nodi e app mobile
- **Instradamento**: Pacchetti correttamente instradati anche senza BLE diretto
- **Integrazione hardware**: Heltec + BME280 + firmware Meshtastic funzionanti perfettamente
- **Affidabilità**: Rete resiliente con fallback automatico tra percorsi

## 📖 Relazione Tecnica

Per una spiegazione dettagliata dell'architettura della rete, dell'implementazione hardware e software, e dei risultati dei test, consultare il documento tecnico in `docs/` in cui è possibile trovare la tesi, che copre:

- **Analisi tecnica**: Architettura della rete mesh e topologia
- **Integrazione hardware**: Configurazione dei nodi Heltec e sensori BME280
- **Sviluppo dell'app**: Struttura di MeshView e logica BLE
- **Test e prestazioni**: Risultati di copertura, latenza e affidabilità della rete

## ⚠️ Disclaimer

Questo progetto è stato sviluppato come lavoro di tesi universitaria a scopo didattico e formativo all'interno di un ambiente accademico.

L'obiettivo è dimostrare l'implementazione pratica di reti mesh LoRa per applicazioni off-grid e il monitoraggio ambientale distribuito. L'autore non si assume alcuna responsabilità per l'uso improprio del codice o delle informazioni contenute in questa repository.


Progetto realizzato a scopo didattico e formativo.

**GitHub**: [Link al profilo]

Per domande, suggerimenti o feedback, sentiti libero di aprire una issue o di contattarmi.
