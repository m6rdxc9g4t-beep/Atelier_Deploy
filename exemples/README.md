# Exemples de la suite

Neuf histoires **fictives** suivies d'une app à l'autre, avec les mêmes chiffres partout :
Convert → Tab → Viz → Trésorerie → Nexus → Projets → Wiki.

| Histoire | Secteur |
|---|---|
| Studio Garance | Compta (clôture d'un studio de design) |
| Rénovation Urbaine 2026 | Chantier |
| App E-Commerce v2 | Produit |
| Consultant data freelance (Julien Morel, fictif) | Freelance |
| Lemaire Patrimoine | Finance |
| Campagne Brume | Marketing |
| Arpège Courtage | Assurance |
| Librairie Les Pages Vives | Boutique |
| SCI Les Tilleuls | Immobilier |

## Utilisation (rien à lancer ici)

Chaque app a un panneau **Exemples de la suite** : choisir une histoire, **Charger l'exemple**, puis suivre
« Ensuite, … » vers l'app suivante. L'histoire choisie est mémorisée (`localStorage["atelier:exemple"]`).
Ordre conseillé : Convert, Tab, Viz, Trésorerie, puis Nexus (il retrouve le jeu Viz et la story Projets : chargez
Viz et Projets avant lui), Projets, Wiki. Chaque panneau retire aussi ce qu'il a chargé, sans toucher au reste
(Trésorerie : opérations, comptes et budgets de l'exemple seulement ; budgets existants jamais modifiés).

## Modifier une histoire

Les données sont dans `histoires/<histoire>.py` (helpers communs : `histoires/commun.py`). Puis :

```bash
python3 exemples/generer.py --vers ~/dev        # dossier qui contient les dépôts des apps
```

Le générateur vérifie l'histoire (soldes jamais négatifs, alerte Viz bien déclenchée, une catégorie garde le même
sens dans toutes les histoires), écrit `exemples/dist/` et copie `exemples-suite/` dans chaque dépôt
(format `atelier-exemples/1`) : un `index.json` (histoires et parcours) et un `<histoire>.json` par app, plus les
relevés PDF et CSV pour Convert. Sortie reproductible : relancer sans rien changer ne modifie aucun fichier.
Ne jamais modifier `exemples-suite/` à la main dans un dépôt d'app. Identifiants partagés : projet Tab
`prj_ex_<histoire>`, tables `tbl_ex_<histoire>_<n>` (0 = opérations), jeu Viz `exemple:<histoire>:operations`.

Les images Docker embarquent `exemples-suite/` de chaque app (`docker/*.Dockerfile`) ; l'interface de Tab
l'intègre à sa construction (`caddy/Dockerfile`), et Nexus charge l'histoire dans `data/atelier_tab` par le
serveur MCP de Tab.
