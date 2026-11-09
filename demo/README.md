# Kit de démo « Studio Garance »

Un jeu de données **fictif** qui traverse la suite : trois relevés bancaires d'un petit studio de design (août à octobre 2026) passent par Convert, Tab, Viz, Trésorerie, Nexus, Projets et Wiki. C'est l'exemple guidé de la suite, chargé dans les vraies apps du VPS.

```bash
cd ~/Ateliers/Atelier_Deploy          # ou là où est cloné le dépôt
sudo ./demo/charger.sh                 # charge tout (≈ 10 s)
sudo ./demo/charger.sh etat            # ce qui est chargé
sudo ./demo/charger.sh retirer         # enlève tout ce que le kit a créé, et seulement cela
sudo ./demo/charger.sh charger --apps viz,projets   # une partie seulement
```

Il faut que les apps tournent (`sudo docker compose ps`) et `python3` sur le serveur (présent sur Debian et Ubuntu). Rien à installer : le script n'utilise que la bibliothèque standard, et il parle aux apps en `127.0.0.1` sur leurs ports, comme Nexus.

## Ce qui est chargé

| App | Contenu | Où le voir |
|---|---|---|
| **Convert** | 3 conversions « Relevé août / septembre / octobre 2026 — Studio Garance (démo) », lues depuis les PDF de `donnees/`, soldes contrôlés justes | Historique |
| **Tab** | Espace « Studio Garance (démo) » › projet « Compta 2026 » : 3 tables envoyées par Convert, avec une colonne **Catégorie** | Côté serveur (`data/atelier_tab/`), donc pour Nexus. Voir « À savoir » |
| **Viz** | Jeu « Studio Garance — opérations août-oct. 2026 (démo) » (41 lignes) et alerte « Matériel du mois (démo) » : 708 € pour un seuil de 600 €, **déclenchée** | Jeux de données, Alertes |
| **Trésorerie** | Compte « Compte pro Studio Garance (démo) », 41 opérations catégorisées, budgets d'octobre 2026 (Matériel dépassé) | Comptes, Budgets › octobre 2026 |
| **Projets** | Projet « Gestion 2026 — Studio Garance (démo) » : phase, epic, story *Suivi des budgets*, 3 tâches (dont celle de l'alerte), temps passés, jalon atteint | Projets |
| **Wiki** | Espace « Studio Garance (démo) » : procédure de clôture, une page par mois, fournisseurs, reliées par `[[…]]` | Espaces |
| **Nexus** | Workflows « Dernière conversion Convert → Tab → Viz » et « Alerte Viz → tâche de suivi Projets » (modèles de la bibliothèque, paramètres remplis), plus un déclencheur sur `viz.alert.triggered` filtré sur l'alerte de démo | Workflows |

Parcours conseillé : Convert → Tab → Viz → Trésorerie → Nexus → Projets → Wiki.

Dans Nexus :
- **Lancer** le premier workflow : il reprend le relevé d'octobre, l'envoie dans Tab, le publie dans Viz et calcule débits et crédits par mois.
- Sur le second, **Tester** le déclencheur avec l'événement d'exemple : il crée une tâche de suivi dans la story de démo.

Chaque étape attend « Autoriser ».

## À savoir

- **Trésorerie, c'est votre vraie base.** Le compte de démo apparaît dans le tableau de bord tant qu'il est chargé. Le kit ne modifie rien d'existant :
  - une catégorie du même nom que les siennes est réutilisée ;
  - un budget d'octobre 2026 déjà posé sur une catégorie est laissé tel quel (le script le signale).

  `retirer` supprime le compte et ses opérations, les budgets que le kit a posés, et les catégories qu'il a créées si plus rien ne les utilise.
- **L'interface web de Tab ne voit pas ces tables.** Elle garde ses données dans le navigateur (IndexedDB), le serveur MCP de Tab dans `data/atelier_tab/`. Pour avoir les opérations dans le Tab du navigateur, importez `donnees/operations_2026-08_2026-10.csv`.
- **`data/atelier_tab/atelier.json`.** S'il n'existait pas, le kit le crée, ce qui rend aussi le serveur MCP de Tab utilisable par Nexus. `retirer` le supprime s'il ne contient plus rien. S'il existait, une copie de sécurité `atelier.json.avant-demo-…` est faite avant l'ajout de l'espace de démo.
- **Nexus n'a pas encore de nœud Wiki.** Les pages du Wiki sont écrites par le kit, pas par un workflow. La tâche « Alerte… » de Projets est aussi créée par le kit, comme le ferait le workflow d'alerte ; tester le déclencheur en crée une seconde.
- **Ce que les workflows de démo créent en tournant est aussi retiré** :
  - les tables du projet Tab de démo ;
  - les jeux Viz dont le nom finit par « Studio Garance (démo) » ;
  - les tâches de la story de démo ;
  - les exécutions des workflows supprimés.
- Le kit note ce qu'il crée dans `data/demo/studio-garance.json` (compris dans `backup.sh`). Une app déjà chargée est sautée : pour recommencer, `retirer` puis `charger`.

## Fichiers

```
demo/
├── charger.sh              point d'entrée (sudo)
├── kit.py                  chargement, état, retrait
├── donnees/
│   ├── studio-garance.json source unique : opérations, budgets, noms
│   ├── releve_2026-08.pdf  relevés « Débit / Crédit » au format lu par Convert
│   ├── releve_2026-09.pdf
│   ├── releve_2026-10.pdf
│   └── operations_2026-08_2026-10.csv   CSV français (Trésorerie, Tab)
└── outils/fabriquer.py     régénère PDF et CSV depuis le JSON (reportlab, hors VPS)
```

Les PDF et le CSV peuvent aussi servir à la main : déposer un relevé dans Convert, importer le CSV dans Trésorerie ou dans Tab.

Le kit a été essayé contre les vraies apps (Convert, Viz, Trésorerie, Projets, Wiki, Nexus et son PostgreSQL, serveur MCP de Tab), lancées sur les ports du VPS : chargement, lancement des deux workflows Nexus jusqu'au bout, retrait complet puis rechargement.
