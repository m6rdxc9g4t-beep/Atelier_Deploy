---
version: 1
slug: "portail-public-index-html"
primary_target: "portail/public/index.html"
related_targets: ["portail/public/connexion.html"]
---

## Scope
Portail de la Suite Atelier : `portail/public/index.html` (sélecteur d'apps + état du serveur) et `portail/public/connexion.html`. Mode : Operate. Utilisateur : François, seul, surtout sur Mac. Tâche : ouvrir la bonne app en une action, voir ce qui est tombé. Contrainte : Node sans dépendance, pas de build ; le fichier `portail/public/atelier.css` est le système commun que les autres apps reprendront.

## Direction contract
THESIS: Le portail est un lanceur d'outil, pas une page d'accueil : barre latérale + liste dense, clavier d'abord, au niveau de finition de Linear (canon choisi par François le 6 nov. 2026, standard joué franc). Refuse la grille de tuiles illustrées néon.
OWN-WORLD: Inter variable auto-hébergée, 13 px de base ; neutres froids, thème clair et sombre (choix Système/Clair/Sombre partagé par cookie entre sous-domaines) ; un accent indigo pour sélection et focus ; chaque app = icône carrée arrondie en dégradé de sa couleur, glyphe trait blanc ; états vert/ambre/rouge seulement quand ils signifient.
STORY: François voit d'un coup d'œil « 13 sur 14 en ligne », tape quelques lettres ou un chiffre, Entrée, il est dans l'app.
FIRST VIEWPORT: Barre latérale 232 px (marque, recherche ⌘K, Toutes/Récentes/Incidents, groupes, thème, compte en pied). Zone principale : barre haute 44 px (titre de la vue, bascule Liste/Icônes, Nouvel onglet, santé + heure), puis groupes d'apps en lignes de 40 px : touche, icône, nom, rôle, état, latence, flèche.
FORM: canon (standing exit, catégorie lanceur/tableau de bord à la Linear), hors liste ; seed:25528ce822e39350
SIGNATURE: sélection au clavier (↑↓←→, Entrée, ⌘Entrée) qui suit aussi la souris, la recherche filtre en direct et Entrée ouvre le premier résultat.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
