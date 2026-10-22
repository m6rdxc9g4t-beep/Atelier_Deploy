# Suite Atelier sur VPS

Nexus, Viz, Tab et Projets sur ton VPS OVH, derrière un portail où tu choisis l'app à ouvrir. Une seule connexion vaut pour toute la suite, en HTTPS.

```
https://atelier.mondomaine.fr            portail : choix de l'app + connexion
https://nexus.atelier.mondomaine.fr      Atelier Nexus
https://viz.atelier.mondomaine.fr        Atelier Viz
https://tab.atelier.mondomaine.fr        Atelier Tab
https://projets.atelier.mondomaine.fr    Atelier Projets
```

## Installation (≈ 30 minutes, dont 15 de construction)

### 1. Ce qu'il te faut

- Un VPS OVH sous **Ubuntu 24.04** ou Debian 12, **4 Go de RAM** conseillés (2 Go passent : le script ajoute du swap).
- Un nom de domaine (chez OVH ou ailleurs).
- Un **jeton GitHub** en lecture seule pour cloner tes dépôts privés : GitHub → Settings → Developer settings → *Fine-grained tokens* → *Generate new token*. Accès : `Atelier_Nexus`, `Atelier_Viz`, `atelier-tab`, `Atelier_Projets`. Permission : *Contents : Read-only*.
- Facultatif : une clé API Anthropic pour les agents de Nexus et l'assistant de Viz.

### 2. DNS

Dans l'espace client OVH → *Noms de domaine* → ton domaine → *Zone DNS* → *Ajouter une entrée* :

| Sous-domaine | Type | Cible |
|---|---|---|
| `atelier` | A | IP du VPS |
| `*.atelier` | A | IP du VPS |

Le second enregistrement (joker) couvre `nexus.`, `viz.`, `tab.` et `projets.` d'un coup. Compte quelques minutes de propagation.

### 3. Sur le VPS

```bash
ssh ubuntu@IP_DU_VPS
git clone https://github.com/m6rdxc9g4t-beep/Atelier_Deploy.git
cd Atelier_Deploy
sudo ./install.sh
```

Le script installe Docker, te demande le domaine, ton e-mail, le jeton GitHub et la clé Anthropic, génère le mot de passe du portail, clone les quatre apps, les construit et les lance. À la fin, il affiche l'adresse du portail et ton mot de passe : **note-le**, il reste aussi dans `.env`.

Ouvre `https://atelier.mondomaine.fr`, connecte-toi, choisis ton app.

> Le dépôt `Atelier_Deploy` est privé ? Clone-le avec le même jeton :
> `git clone https://x-access-token:TON_JETON@github.com/m6rdxc9g4t-beep/Atelier_Deploy.git`

## Au quotidien

| Je veux… | Commande (dans `Atelier_Deploy/`) |
|---|---|
| Mettre à jour toutes les apps (dernier commit de `main`) | `sudo ./update.sh` |
| Mettre à jour une seule app | `sudo ./update.sh viz` (ou `nexus`, `tab`, `projets`, `portail`) |
| Voir l'état des conteneurs | `sudo docker compose ps` |
| Lire le journal d'une app | `sudo docker compose logs -f viz` |
| Redémarrer une app | `sudo docker compose restart projets` |
| Sauvegarder | `sudo ./backup.sh` → `backups/atelier-AAAAMMJJ-HHMM.tar.gz` |
| Sauvegarder chaque nuit | `echo "30 3 * * * root $(pwd)/backup.sh >/dev/null" \| sudo tee /etc/cron.d/atelier-backup` |
| Changer le mot de passe | modifier `PORTAL_PASSWORD` dans `.env`, puis `sudo docker compose up -d portail` |
| Déployer une autre branche | `BRANCH_NEXUS=ma-branche` dans `.env`, puis `sudo ./update.sh nexus` |
| Activer l'IA locale (Ollama) | `sudo docker compose --profile ollama up -d`, puis `NEXUS_LLM_PROVIDER=ollama` dans `.env` |

## Comment c'est monté

```
Internet ──443──▶ Caddy ──▶ portail :9000   (connexion, choix de l'app, /auth/verify)
                    │
                    ├─ viz.…      ──▶ Viz :8000           (API + interface, DuckDB)
                    ├─ tab.…      ──▶ fichiers statiques  (interface web de Tab)
                    ├─ projets.…  ──▶ fichiers statiques + /api ──▶ Projets :3000 (SQLite)
                    └─ nexus.…    ──▶ Nexus interface :3100 + /api ──▶ Nexus API :8100
                                                             ├─▶ PostgreSQL :5433
                                                             └─▶ MCP d'Atelier Tab (node, dans le conteneur)
```

- **Tout écoute sur 127.0.0.1.** Viz et Nexus n'acceptent de parler aux autres apps de la suite que sur `127.0.0.1` (contrat `atelier-node/1`). Les conteneurs partagent donc le réseau de l'hôte, et seul Caddy ouvre les ports 80 et 443.
- **Connexion unique.** Caddy demande au portail (`forward_auth`) si chaque requête vient d'une personne connectée. Le cookie de session est posé sur `atelier.mondomaine.fr` et ses sous-domaines. Les apps n'ont pas de login propre : sans le portail, elles seraient ouvertes à tous.
- **Sondes publiques.** Seules les adresses `/api/health` répondent sans connexion. Elles ne disent que « ok » et servent au sélecteur de suite intégré à chaque app.
- **Sélecteur de suite dans les apps.** Les liens Viz ↔ Tab ↔ Projets ↔ Nexus de chaque app sont compilés avec tes sous-domaines : tu passes d'une app à l'autre sans repasser par le portail.
- **Données** dans `data/` : `viz/` (DuckDB, rapports), `projets/` (SQLite + sauvegardes automatiques), `nexus/` (réglages `.env`), `atelier_tab/` (fichiers que le MCP de Tab lit et écrit pour Nexus). Base de Nexus dans le volume Docker `atelier_postgres_data`.

## À savoir

- **Tab dans le navigateur garde ses données dans le navigateur.** L'interface web de Tab enregistre tes tables dans IndexedDB, sur l'appareil qui l'ouvre. Ce que Nexus écrit dans Tab passe par le serveur MCP, qui travaille sur les fichiers de `data/atelier_tab/`. Les deux ne se voient pas. Pour les réunir, il faudrait brancher l'adaptateur `restAdapter` déjà présent dans Tab sur un petit service de stockage côté VPS.
- **Envoi Tab → Projets depuis le navigateur.** L'export par défaut vise `http://127.0.0.1:3000`, c'est-à-dire ton propre ordinateur. Sur le VPS, depuis Tab : passe en mode en ligne, mets `https://projets.atelier.mondomaine.fr/api/imports/atelier-tab` comme adresse. La route d'import n'autorise en CORS que les origines locales : tant que Projets ne l'ouvre pas à `https://tab.…`, cet envoi précis reste bloqué. Les workflows Nexus Tab → Projets, eux, fonctionnent (ils passent par le serveur).
- **Claude par abonnement (CLI).** Les images utilisent la clé API Anthropic (`CLAUDE_MODE=api`). Le mode CLI de Viz et Nexus n'est pas installé dans les conteneurs.
- **Analyse Git de Projets.** Elle lit un dépôt local (`localRepoPath`) : sur le VPS, il faudrait que le dépôt soit cloné dans le conteneur. Le reste de Projets fonctionne normalement.
- **Autres ateliers** (Ciné, Savoir, Trésorerie) : désactivés dans Nexus (`data/nexus/.env`). Cuisine, en ligne, reste branchable depuis l'écran Réglages de Nexus.

## Dépannage

| Symptôme | Piste |
|---|---|
| Le navigateur signale un certificat invalide | Le DNS ne pointe pas encore vers le VPS. Vérifie avec `dig +short viz.atelier.mondomaine.fr`, puis `sudo docker compose logs caddy`. |
| « 403 FORBIDDEN_HOST » dans Projets ou Viz | `ATELIER_DOMAIN` dans `.env` ne correspond pas à l'adresse tapée. Corrige-le, puis `sudo docker compose up -d --build`. |
| Une tuile du portail reste « Hors ligne » | `sudo docker compose logs -f <app>` : souvent une migration ou une variable manquante. |
| La construction s'arrête sans message (« Killed ») | Manque de mémoire : vérifie que le swap est actif (`swapon --show`). |
| Nexus : « Migrations non appliquées » | PostgreSQL pas prêt au premier démarrage. `sudo docker compose restart nexus-backend`. |
