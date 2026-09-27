# Contribuer à Industrial Simulator

Merci de votre intérêt ! Ce projet est jeune (Phase 0) : le meilleur point d'entrée est le [ROADMAP.md](ROADMAP.md).

## Règles du projet

1. **Une responsabilité par fichier** : jamais de fichier monolithique contenant toute la logique.
2. **La simulation ne dépend jamais directement d'OpenPLC** (ni d'aucun PLC) : tout passe par l'abstraction I/O.
3. **Les protocoles industriels sont isolés** derrière le contrat `PlcLink` (voir [ARCHITECTURE.md](ARCHITECTURE.md)).
4. **Le cœur de simulation est testable sans ouvrir Godot** : les tests tournent en headless.
5. **Toute fonctionnalité importante arrive avec ses tests.**
6. **Toute décision architecturale non triviale est consignée** dans [docs/architecture/decisions.md](docs/architecture/decisions.md).
7. **Pas de fonctionnalité hors roadmap** : le roadmap fixe l'ordre des priorités.
8. **Pas de nouvelle dépendance importante sans justification écrite** (ADR).
9. **Aucune mention de nom de produit commercial ou de marque tierce** dans les fichiers, la documentation ou les messages de commit : le projet se décrit par lui-même.

## Workflow

1. Créez une branche : `feat/phase1-moteur-io` ou `fix/description-courte`.
2. Codez en respectant le style des fichiers existants (GDScript typé, indentation 4 espaces, commentaires en français).
3. Lancez les tests : `scripts/run_tests.bat` (Windows) ou `scripts/run_tests.sh` (bash). Ils doivent tous passer.
4. Mettez à jour la documentation concernée (README, ARCHITECTURE, docs/…).
5. Ouvrez une pull request en décrivant le quoi et le pourquoi.

## Messages de commit

Format : `phaseN: résumé court` ou `fix: résumé court`, en français, impératif.

## Licence

En contribuant, vous acceptez que vos contributions soient publiées sous licence MIT (voir [LICENSE](LICENSE)).
