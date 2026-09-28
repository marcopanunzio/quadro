# Personal Dashboard

Dashboard personale per macOS: calendario, promemoria, meteo, compleanni e mail non lette in un'unica finestra.
Legge e scrive direttamente su Calendario e Promemoria di Apple.

## Requisiti

- macOS 26 o successivo
- Swift 6.2 (bastano i Command Line Tools, Xcode non serve)

## Comandi

```sh
scripts/create-signing-cert.sh   # una volta: certificato locale per firmare l'app
scripts/run.sh                   # compila, assembla e avvia l'app
scripts/run.sh --mock            # avvia con dati finti
scripts/test.sh                  # test
scripts/bundle.sh release        # build/PersonalDashboard.app
```

## Struttura

- `Sources/DashboardCore`: modelli, logica, temi, protocolli dei servizi, mock. Nessuna dipendenza da framework di sistema oltre Foundation.
- `Sources/DashboardServices`: EventKit, CoreLocation, Open-Meteo, AppleScript verso Mail.
- `Sources/PersonalDashboard`: app SwiftUI.
