# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
François, seul, pour l'essentiel de la suite : ses propres outils de travail et de vie personnelle, ouverts surtout sur son Mac (grand écran), le téléphone en second.
Exceptions confirmées :
- **Portfolio** : public, lu par des recruteurs (vitrine de projets d'économétrie, CV, contact).
- **Dates, Suivi et Cuisine** : utilisées à deux (François et sa/son partenaire), sur Vercel avec leur propre connexion.

## Product Purpose
La suite Atelier est un ensemble d'une vingtaine d'apps personnelles auto-hébergées (VPS OVH, Docker, Caddy) ou en ligne (Vercel + Supabase). Le portail est la porte d'entrée : une connexion unique, puis le choix de l'app à ouvrir, avec l'état de chaque service du serveur. Réussite : arriver dans la bonne app en une action, savoir d'un coup d'œil si quelque chose est tombé.

## Positioning
Une suite d'outils entièrement possédée par une seule personne : même serveur, même connexion, même IA locale (Ollama) partagée par toutes les apps. Ce n'est pas un SaaS ni un produit vendu ; c'est un atelier personnel dont chaque app est un établi.

## Operating Context
- Portail : https://atelier.141-227-149-233.sslip.io (domaine provisoire), identifiant unique, cookie partagé par les sous-domaines, `forward_auth` Caddy.
- Trois familles d'apps dans le portail : **sur le serveur** (Nexus, Viz, Tab, Projets, Wiki, Formulaire, Trésorerie, Savoir, Ciné, Convert, Portfolio), **Sites & tests** (Ops Lab, Mission, DataMind), **apps en ligne** avec leur propre connexion (Suivi, Dates, Cuisine).
- Raccourcis clavier 1–9 et 0 pour ouvrir une app ; état sondé côté serveur toutes les 20 s.
- Agents liés : Agent_Data (DataMind), Atelier_agent-AvP, agent-ops-lab (Ops Lab).

## Capabilities and Constraints
- Portail en Node 22 sans dépendance (`portail/server.mjs`), pages HTML statiques avec gabarits `{{…}}` ; aucune étape de build.
- Apps dans des dépôts séparés et des technos différentes (Node, Python, React/Vite, Next.js) : un système de design commun doit pouvoir être copié dans chacune sans outillage partagé.
- Toutes les interfaces sont en français, tutoiement.
- IA locale lente sans GPU (secondes à minutes par réponse).

## Brand Commitments
- Nom : « Suite Atelier » ; chaque app s'appelle « Atelier <Nom> ».
- Les logos néon et les couleurs actuelles par app ne sont pas figés (confirmé par François le 6 nov. 2026) : tout peut changer.
- Un seul système de design commun à toute la suite ; chaque app peut garder un accent propre (choix de François, 6 nov. 2026).

## Evidence on Hand
- Logos actuels : `portail/public/logos/<id>.webp` (remplaçables).
- Pas de témoignages, chiffres d'usage ni clients : rien de tel ne doit être inventé.

## Product Principles
1. Une action pour arriver dans l'app : le portail est un aiguillage, pas une page d'accueil.
2. L'état du serveur se lit sans effort : ce qui est tombé se voit tout de suite.
3. Une suite, une famille : une app reconnue comme Atelier dès son premier écran.
4. Outil d'abord : densité et précision sur Mac, le téléphone doit rester confortable.
