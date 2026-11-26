# Карта кода

GitHub рисует эти схемы сам. Обновлять вручную при добавлении модуля или RemoteEvent.

## Кто кого требует (require)

```mermaid
graph LR
  subgraph Shared["ReplicatedStorage.Shared"]
    Config
    RoundLogic
  end
  subgraph Server["ServerScriptService.Server"]
    init["init.server"]
    Spec["Tests/RoundLogic.spec"]
    RoundService
    AIHost
    Goals
    Threats
    Players["Players (Roster)"]
    Arena
    WordService
    ModelCache
    Remotes
  end
  subgraph Client["StarterPlayerScripts.Client"]
    initc["init.client (HUD)"]
    Voice
  end

  init --> Remotes & Arena & Players & RoundService
  init -. только Studio .-> Spec
  Spec --> RoundLogic & Config & Goals & Threats
  RoundService --> AIHost & Goals & Threats & Players & Arena & WordService & ModelCache & Remotes & Config
  AIHost --> RoundLogic & Config
  WordService --> RoundLogic & Config & Remotes
  Goals --> Arena & Players & Config
  Threats --> Arena & Players & ModelCache
  Players --> Arena
  RoundLogic --> Config
  initc --> Voice & Config
```

Правило: `Shared` не знает о сервере и клиенте; `Players`/`Arena` — нижний слой сервера, их требуют все, они — никого, кроме друг друга.

## Сеть (RemoteEvent)

```mermaid
graph LR
  RS[RoundService] -- "Announce(text, isAISays, voice)" --> C[Клиент: HUD + Voice]
  RS -- "State{phase, timeLeft, alive, round, streak, goal?}" --> C
  WS[WordService] -- "AskWord(seconds) — только победителю" --> C
  C -- "SubmitWord(word) → cleanWord + TextService-фильтр" --> WS
```

## Один раунд

```mermaid
sequenceDiagram
  participant RS as RoundService
  participant AI as AIHost
  participant G as Goals/Threats
  participant P as Players (Roster)
  participant WS as WordService
  participant MC as ModelCache
  RS->>AI: buildRound(word)
  AI-->>RS: Round (ИИ или резерв)
  RS->>P: startRound() — все на арену
  opt 30%
    RS->>P: ловушка «Прыгайте!» → eliminate(прыгнувших)
  end
  RS->>G: goal(ctx), threat(ctx)
  G->>P: eliminate(...) во время раунда
  RS->>G: stopThreat(), finishGoal()
  RS->>WS: ask(случайный выживший)
  WS-->>RS: слово
  RS->>MC: request(word) — 3D-модель в фоне
```
