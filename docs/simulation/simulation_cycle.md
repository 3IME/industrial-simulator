# Le cycle de simulation

## Principe

Le `SimulationEngine` exécute un **cycle déterministe** à pas de temps fixe, calqué sur le fonctionnement réel d'un automate : l'image d'entrées est figée, traitée, puis les sorties sont appliquées. Rien ne bouge entre deux cycles.

## Les 6 temps d'un cycle (`step(dt)`)

| Temps | Appel | Description |
|---|---|---|
| 1 | `scan_inputs(io)` | Les machines publient capteurs et états dans la table d'E/S (entrées PLC). |
| 1b | `mark_stale_inputs` | **Watchdog qualité** (si `input_timeout_usec > 0`) : toute entrée non rafraîchie depuis ce délai est marquée `BAD`. |
| 2 | `publish_inputs(io)` | Le lien PLC transmet les entrées à l'automate (en Modbus : l'automate vient les lire ; en Phase 0, le lien est `NullPlcLink`). |
| 3 | `pull_outputs(io)` | Le lien PLC récupère les sorties écrites par l'automate. |
| 4 | `apply_outputs(io)` | Les sorties PLC sont appliquées aux actionneurs (commandes des machines). |
| 5 | `update(dt)` | La simulation avance : physique et logique des machines. |
| 6 | `refresh_sensors(dt)` | Les capteurs recalculent leur état brut — **il ne sera lu qu'au temps 1 du cycle suivant**. |

```
      ┌──────────────────────────────────────────────┐
      │                                              │
      ▼                                              │
 1. scan_inputs ──► 2. publish_inputs ──► 3. pull_outputs
                                                        │
                                                        ▼
 6. refresh_sensors ◄── 5. update(dt) ◄── 4. apply_outputs
```

## Pourquoi les capteurs sont rafraîchis *après* la mise à jour

Cela reproduit le **décalage de scrutation** d'une vraie chaîne automate/capteur : un état physique produit au cycle N n'est visible par le PLC qu'au cycle N+1. Ce décalage d'un pas est volontaire et documenté — le tester, c'est prouver que le simulateur se comporte comme une usine réelle et non comme un programme couplé.

## Déterminisme

* Pas de temps `dt` fixe, fourni au moteur ; aucune horloge OS dans le cœur.
* Le moteur tient une **horloge simulée** (`sim_time_usec`, +`round(dt × 10⁶)` par pas) qu'il injecte dans la table : tous les horodatages sont reproductibles au microseconde près (ADR-010).
* `advance(secondes, dt)` exécute exactement `round(secondes / dt)` cycles — même nombre, même ordre, mêmes résultats à chaque exécution.

Le pilotage temps réel (accumuler le temps réel dans un `Node` Godot et appeler `step()` le bon nombre de fois) arrive en Phase 5. Le timestep est déjà **configurable par usine** via `factory.json` (`simulation.timestep`).

## Exemple concret (convoyeur, dt = 1/60 s)

1. Une boîte atteint le capteur d'entrée pendant `update` → `refresh_sensors` passe `sensor_entry` à `true` (fin du cycle N).
2. Cycle N+1, `scan_inputs` : `%IX0.0 = true` dans la table.
3. OpenPLC (ladder : « si %IX0.0 alors %QX0.0 ») écrit `%QX0.0 = true`.
4. `pull_outputs` puis `apply_outputs` : `conveyor_01.run = true` → le convoyeur démarre au temps 5.
5. La boîte avance… atteint le capteur de sortie → même mécanisme → `%QX0.0 = false` → arrêt.
