# Suite Atelier sur VPS

La suite Atelier sur ton VPS OVH, derrière un portail où tu choisis l'app à ouvrir. Une seule connexion vaut pour toutes les apps du serveur, en HTTPS.

- **Hébergées sur le VPS**, derrière la connexion du portail : Nexus, Viz, Tab, Convert, Projets, Wiki, Formulaire, Trésorerie, Savoir, Ciné.
- **Vitrine pro**, hébergée sur le VPS et **publique** (sans connexion) : le Portfolio, ses démos interactives (observatoire immobilier, e-commerce temps réel, labo A/B et causal, prévision de ventes, SQL Lab, qualité des données, tableau de bord, modélisation de données, segmentation clients, élasticité-prix, score de churn, labo de régression, attribution marketing, pipeline de données, impact sans groupe témoin, durée de vie client), **DataMind en direct** (la vraie app en mode démo, voir « DataMind ») et **Ops Lab**. Chaque entrée du portail a un bouton « Copier le lien public » (adresse `PORTFOLIO_PUBLIC_URL`, par ex. le relais Netlify). Les démos du Portfolio et Ops Lab tournent dans le navigateur du visiteur ; la démo de DataMind n'a que l'IA du serveur. Aucune IA payante.
- **Sites & tests**, hébergés sur le VPS derrière la connexion du portail, dans leur propre section : simulations, maquettes et essais. Pour l'instant : **DataMind** (agent d'analyse de données, l'app complète avec son IA) et **Mission** (Atelier Mission, le mini-CRM freelance : prospects, devis, factures Malt et directes, relances).
- **En ligne, sur Vercel uniquement** (Vercel + Supabase, avec sa propre connexion), sous forme de lien dans le portail : Suivi, Dates et Cuisine. Elles se mettent à jour toutes seules à chaque commit ; les anciennes adresses `dates.…` et `suivi.…` du VPS redirigent vers Vercel.

```
https://atelier.mondomaine.fr            portail : choix de l'app + connexion
https://nexus.atelier.mondomaine.fr      Atelier Nexus
https://viz.atelier.mondomaine.fr        Atelier Viz
https://convert.atelier.mondomaine.fr    Atelier Convert
https://tab.atelier.mondomaine.fr        Atelier Tab
https://projets.atelier.mondomaine.fr    Atelier Projets
https://wiki.atelier.mondomaine.fr       Atelier Wiki
https://formulaire.atelier.mondomaine.fr Atelier Formulaire
https://tresorerie.atelier.mondomaine.fr Atelier Trésorerie
https://savoir.atelier.mondomaine.fr     Atelier Savoir
https://cine.atelier.mondomaine.fr       Atelier Ciné
https://dates.atelier.mondomaine.fr      → redirige vers Atelier Dates (Vercel)
https://suivi.atelier.mondomaine.fr      → redirige vers Atelier Suivi (Vercel)
https://portfolio.atelier.mondomaine.fr  Portfolio (public)
https://ops.atelier.mondomaine.fr        Ops Lab (Sites & tests)
https://mission.atelier.mondomaine.fr    Atelier Mission (Sites & tests)
https://datamind.atelier.mondomaine.fr   DataMind (Sites & tests)
https://demo-datamind.atelier.mondomaine.fr  DataMind, démo publique (Vitrine pro)
```

Pas de nom de domaine ? `atelier.<IP-avec-tirets>.sslip.io` (par exemple `atelier.141-227-149-233.sslip.io`) fonctionne sans aucune configuration DNS.

## Installation (≈ 30 minutes, dont 15 de construction)

### 1. Ce qu'il te faut

- Un VPS OVH sous Debian 12/13 ou Ubuntu 24.04, **4 Go de RAM** conseillés pour les 10 apps (le script ajoute du swap en dessous de 6 Go).
- Un nom de domaine (chez OVH ou ailleurs).
- Un **jeton GitHub** en lecture seule pour cloner tes dépôts privés : GitHub → Settings → Developer settings → *Fine-grained tokens* → *Generate new token*. Accès : `Atelier_Deploy`, `Atelier_Nexus`, `Atelier_Viz`, `atelier-tab`, `Atelier_Convert`, `Atelier_Projets`, `Atelier_Wiki`, `Atelier_Formulaire`, `Atelier_Cine`, `Atelier-Savoir`, `Atelier_Tr-sorerie`. Permission : *Contents : Read-only*. (`Agent_Data`, `Atelier_Portefolio`, `agent-ops-lab` et `Atelier_Mission` sont publics : rien à ajouter.)
- Facultatif : une clé API Anthropic pour les agents de Nexus et l'assistant de Viz.

### 2. DNS

Dans l'espace client OVH → *Noms de domaine* → ton domaine → *Zone DNS* → *Ajouter une entrée* :

| Sous-domaine | Type | Cible |
|---|---|---|
| `atelier` | A | IP du VPS |
| `*.atelier` | A | IP du VPS |

Le second enregistrement (joker) couvre tous les sous-domaines des apps d'un coup. Compte quelques minutes de propagation.

### 3. Sur le VPS

```bash
ssh ubuntu@IP_DU_VPS
git clone https://github.com/m6rdxc9g4t-beep/Atelier_Deploy.git
cd Atelier_Deploy
sudo ./install.sh
```

Le script installe Docker, te demande le domaine, ton e-mail, le jeton GitHub et la clé Anthropic, génère le mot de passe du portail, clone les apps, les construit et les lance. À la fin, il affiche l'adresse du portail et ton mot de passe : **note-le**, il reste aussi dans `.env`.

Ouvre `https://atelier.mondomaine.fr`, connecte-toi, choisis ton app.

> Le dépôt `Atelier_Deploy` est privé ? Clone-le avec le même jeton :
> `git clone https://x-access-token:TON_JETON@github.com/m6rdxc9g4t-beep/Atelier_Deploy.git`

## Au quotidien

| Je veux… | Commande (dans `Atelier_Deploy/`) |
|---|---|
| Mettre à jour toutes les apps (dernier commit de `main`) | `sudo ./update.sh` (une app après l’autre pour ménager le disque : compter 30 à 45 min ; il faut au moins 3 Go libres) |
| Mettre à jour une seule app | `sudo ./update.sh viz` (ou `nexus`, `tab`, `convert`, `datamind` (+ sa démo publique), `projets`, `wiki`, `formulaire`, `tresorerie`, `savoir`, `cine`, `portfolio`, `ops`, `mission`, `portail`) |
| Mettre à jour automatiquement, comme Vercel (à chaque commit sur GitHub) | `sudo ./auto-update.sh install` une fois ; apps suivies dans `AUTO_UPDATE_APPS` (`.env`, aucune par défaut) ; état : `sudo ./auto-update.sh status` |
| Lire les messages reçus par le portfolio | `sudo cat data/portfolio/messages.jsonl` |
| Ajouter des films à Ciné | depuis ton Mac : `rsync -avP ~/Films/ debian@IP:~/Ateliers/Atelier_Deploy/media/films/`, puis « Rescanner » dans Ciné |
| Changer l'adresse de Cuisine, Suivi ou Dates | `CUISINE_URL`, `SUIVI_URL` ou `DATES_URL=https://…` dans `.env`, puis `sudo ./update.sh portail` |
| Voir l'état des conteneurs | `sudo docker compose ps` |
| Lire le journal d'une app | `sudo docker compose logs -f viz` |
| Redémarrer une app | `sudo docker compose restart projets` |
| Exemples de la suite (9 histoires fictives à suivre d'une app à l'autre) | Panneau **Exemples de la suite** de chaque app (voir [`exemples/README.md`](exemples/README.md)) |
| Charger l'exemple guidé (données fictives « Studio Garance » dans Convert, Tab, Viz, Trésorerie, Nexus, Projets, Wiki) | `sudo ./demo/charger.sh` ; l'enlever : `sudo ./demo/charger.sh retirer` (voir [`demo/README.md`](demo/README.md)) |
| Sauvegarder | `sudo ./backup.sh` → `backups/atelier-AAAAMMJJ-HHMM.tar.gz` |
| Sauvegarder chaque nuit | `echo "30 3 * * * root $(pwd)/backup.sh >/dev/null" \| sudo tee /etc/cron.d/atelier-backup` |
| Changer le mot de passe | modifier `PORTAL_PASSWORD` dans `.env`, puis `sudo docker compose up -d portail` |
| Déployer une autre branche | `BRANCH_NEXUS=ma-branche` dans `.env`, puis `sudo ./update.sh nexus` |
| Changer de modèle d'IA | `OLLAMA_MODEL=…` dans `.env` (ex. `llama3.1:8b`, `llama3.2:3b`, `qwen3:8b`), puis `sudo ./update.sh` |
| Retélécharger le modèle d'IA | `sudo ./update.sh ia` |

## Comment c'est monté

```
Internet ──443──▶ Caddy ──▶ portail :9000   (connexion, choix de l'app, /auth/verify)
                    │
                    ├─ viz.…      ──▶ Viz :8000           (API + interface, DuckDB)
                    ├─ convert.…  ──▶ Convert :8010       (API + interface, OCR Tesseract)
                    ├─ datamind.… ──▶ DataMind :3600      (Fastify + DuckDB, interface React ; SSE) ──▶ Ollama
                    ├─ demo-datamind.… ──▶ DataMind démo :3601 (même image, public, sans écriture) ──▶ Ollama
                    ├─ tab.…      ──▶ fichiers statiques  (interface web de Tab)
                    ├─ projets.…  ──▶ fichiers statiques + /api ──▶ Projets :3000 (SQLite)
                    ├─ wiki.…     ──▶ Wiki :3200          (Fastify, SQLite + pièces jointes)
                    ├─ formulaire.… ──▶ Formulaire :3300  (Fastify, SQLite ; /r/* public)
                    ├─ tresorerie.… ──▶ Trésorerie :5050  (Flask, SQLite)
                    ├─ savoir.…   ──▶ Savoir :5051        (Flask, SQLite + fichiers)
                    ├─ cine.…     ──▶ Ciné :4000          (Express, vidéos de media/ en flux)
                    ├─ dates.…, suivi.… ──▶ redirection vers Vercel
                    ├─ portfolio.… ──▶ Portfolio :8787    (Express + React, public, sans connexion)
                    ├─ ops.…      ──▶ Ops Lab :3400       (Next.js autonome ; section Sites & tests)
                    ├─ mission.…  ──▶ Mission :3500       (Fastify, SQLite ; Sites & tests) ──▶ Projets, Trésorerie en 127.0.0.1
                    └─ nexus.…    ──▶ Nexus interface :3100 + /api ──▶ Nexus API :8100
                                                             ├─▶ PostgreSQL :5433
                                                             ├─▶ MCP d'Atelier Tab (node, dans le conteneur)
                                                             └─▶ Viz, Projets, Trésorerie, Savoir, Ciné en 127.0.0.1

Portail ──lien──▶ Cuisine, Dates, Suivi (Vercel + Supabase, hors VPS)
```

- **Tout écoute sur 127.0.0.1.** Viz et Nexus n'acceptent de parler aux autres apps de la suite que sur `127.0.0.1` (contrat `atelier-node/1`). Les conteneurs partagent donc le réseau de l'hôte, et seul Caddy ouvre les ports 80 et 443.
- **Connexion unique.** Caddy demande au portail (`forward_auth`) si chaque requête vient d'une personne connectée. Le cookie de session est posé sur `atelier.mondomaine.fr` et ses sous-domaines. Les apps n'ont pas de login propre : sans le portail, elles seraient ouvertes à tous.
- **Le Portfolio, public.** `portfolio.…` ne passe pas par la connexion du portail : c'est un site vitrine, sans données privées. Seuls les messages du formulaire de contact sont enregistrés, dans `data/portfolio/messages.jsonl`. Il n'appelle aucune IA : sa page DataMind mène à la démo publique (`demo-datamind.…`), dont l'adresse est fixée à la construction (`docker/portfolio.Dockerfile`).
- **Sites & tests.** Une section du portail pour les simulations et maquettes, derrière la même connexion. **Ops Lab** (`ops.…`, dépôt public `agent-ops-lab`) fait tourner toute sa simulation dans le navigateur : rien n'est stocké sur le serveur, la partie est sauvegardée dans le navigateur de chaque appareil. **Mission** (`mission.…`, dépôt public `Atelier_Mission`) garde ses données sur le serveur (`data/mission/`) : il lit le temps saisi dans Projets et écrit les encaissements dans Trésorerie, tous deux en `127.0.0.1` sur ce VPS ; Brevo (relances) et SUPER PDP (facture électronique) ne servent qu'en mode « En ligne » de l'app, avec `MISSION_BREVO_API_KEY` et `MISSION_SUPERPDP_*` dans `.env`. Pour ajouter un autre site : une entrée dans `SITES` (`portail/server.mjs`) et son icône `<symbol id="app-<id>">` dans `portail/public/atelier-icons.svg`, un bloc dans `caddy/Caddyfile`, un service dans `docker-compose.yml` (+ son Dockerfile dans `docker/`), une ligne dans `APPS` (`scripts/lib.sh`) et un cas dans `update.sh`.
- **Sondes publiques.** Seules les adresses `/api/health` répondent sans connexion. Elles ne disent que « ok » et servent au sélecteur de suite intégré à chaque app.
- **Réponse publique de Formulaire.** Exception voulue : la page `/r/<lien secret>`, son API `/api/public/*` et les fichiers de l'interface de `formulaire.…` sont ouverts sans connexion, pour les formulaires que leur auteur a partagés « à toute personne qui a le lien ».
- **Sélecteur de suite dans les apps.** Les liens Viz ↔ Tab ↔ Projets ↔ Nexus de chaque app sont compilés avec tes sous-domaines : tu passes d'une app à l'autre sans repasser par le portail.
- **Données** dans `data/` : `viz/` (DuckDB, rapports), `convert/` (conversions et fichiers déposés), `projets/` (SQLite + sauvegardes automatiques), `nexus/` (réglages `.env`), `atelier_tab/` (fichiers que le MCP de Tab lit et écrit pour Nexus), `wiki/` (`wiki.db` + `uploads/`), `formulaire/` (`formulaire.db`), `tresorerie/` (`finance.db`), `savoir/` (base + fichiers déposés), `cine/` (catalogue, profils), `portfolio/` (messages du formulaire de contact), `datamind/` (jeux de données et analyses de DataMind), `mission/` (`atelier-mission.db` : clients, devis, factures). Vidéos dans `media/films` et `media/series` (lecture seule pour Ciné, non sauvegardées). Base de Nexus dans le volume Docker `atelier_postgres_data`.

## Portfolio à une adresse Netlify

Le Portfolio reste hébergé sur le VPS, mais tu peux donner aux recruteurs une adresse propre, par exemple `https://francois-pichon.netlify.app`.
Netlify n'héberge rien : il relaie chaque requête vers `portfolio.<domaine>` (réécriture 200, `netlify/portfolio/netlify.toml`), et l'adresse Netlify reste affichée.
Les requêtes relayées sont **signées** : le Portfolio reconnaît ainsi l'adresse réelle de chaque visiteur (limite du formulaire de contact, adresse notée avec chaque message).

1. Sur le VPS, mets le kit à jour puis le Portfolio (le secret `PORTFOLIO_PROXY_SECRET` est créé dans `.env` s'il manque), et affiche le secret :
   ```bash
   sudo ./update.sh portfolio
   sudo grep PORTFOLIO_PROXY_SECRET .env
   ```
2. Sur [app.netlify.com](https://app.netlify.com) : *Add new project* → *Import an existing project* → GitHub → `Atelier_Deploy`.
   Dossier de base (*Base directory*) : `netlify/portfolio`. Laisse la commande de build vide, puis déploie.
3. Dans le projet Netlify : *Project configuration* → *Environment variables* → ajoute `PORTFOLIO_PROXY_SECRET` avec la valeur de l'étape 1,
   puis *Deploys* → *Trigger deploy* → *Deploy project* (la signature n'est prise en compte qu'au déploiement suivant).
4. *Project configuration* → *Change project name* → par exemple `francois-pichon` : l'adresse devient `https://francois-pichon.netlify.app`.
5. Vérifie : ouvre l'adresse Netlify, envoie un message de test depuis la page Contact, puis sur le VPS
   `sudo tail -n 1 data/portfolio/messages.jsonl` doit montrer **ton** adresse IP, pas celle d'un serveur Netlify.

L'ancienne adresse `portfolio.<domaine>` continue de marcher. Le jour où le VPS a un vrai domaine, remplace l'adresse dans `netlify/portfolio/netlify.toml`.
Limite de Netlify : une requête relayée qui dure plus de 26 s est coupée (sans effet sur le Portfolio, dont les réponses sont rapides).

## DataMind

Agent d'analyse de données, dans la section **Sites & tests** du portail (dépôt public `Agent_Data`, web app TypeScript : Fastify + DuckDB, React). On dépose un CSV, un Excel, un JSON ou un Parquet, on pose ses questions, et l'agent écrit des requêtes SQL qu'il **exécute réellement** sur les données, avec graphiques, segmentation, modèle prédictif et prévision.

- **Claude avec ton forfait, sans clé API** : sur ton Mac, `claude setup-token` (Claude Code connecté à ton compte Pro ou Max) affiche un jeton `sk-ant-oat01-…` valable un an. Colle-le dans `DATAMIND_CLAUDE_OAUTH_TOKEN` (`.env`), puis `sudo ./update.sh datamind`. DataMind passe par le Claude Agent SDK et consomme les limites de ton abonnement. C'est un usage personnel : ne partage pas l'accès au portail.
- **Sinon** : l'IA du serveur (`OLLAMA_MODEL`), ou Claude par clé API si `ANTHROPIC_API_KEY` est renseignée. `DATAMIND_ENGINE` force le moteur proposé, `DATAMIND_CLAUDE_MODEL` le modèle Claude.
- **Données** : jeux de données (Parquet) et analyses (JSON) dans `data/datamind/`, compris dans les sauvegardes.
- **Sécurité** : les requêtes de l'IA sont en lecture seule, sur une base en mémoire sans accès aux fichiers ; les outils de Claude Code (fichiers, commandes, web) sont désactivés ; l'app est derrière la connexion du portail.
- Installer ou mettre à jour : `sudo ./update.sh datamind` (reconstruit l'image, puis relance aussi la démo publique).

### Démo publique (`https://demo-datamind.<domaine>`)

La même app, en **mode démo**, ouverte à tous depuis la section **Vitrine pro** du portail et le bouton « Essayer la démo » de la page DataMind du Portfolio.

- **Même image** que `datamind` (`atelier-datamind`) : rien de plus à construire ni à stocker. Service `datamind-demo`, `127.0.0.1:3601`, réseau de l'hôte comme les autres.
- **Mode démo** (`DATAMIND_DEMO=1`) : les jeux d'exemple seulement, aucun import ni écriture, une session par visiteur ; son lien « Portfolio » ramène à `PORTFOLIO_PUBLIC_URL` (sinon `portfolio.<domaine>`).
- **IA du serveur seulement** : ni jeton du forfait, ni clé Anthropic dans ce service. `DATAMIND_DEMO_QUESTIONS_PAR_HEURE` (`.env`, 10 par défaut) questions par heure et par visiteur, une à la fois. Caddy pose `X-Forwarded-For` (l'adresse réelle) et l'app ne le lit que depuis `127.0.0.1` : chaque visiteur a son propre quota.
- **Données éphémères** : les jeux d'exemple sont copiés au démarrage dans un `tmpfs` de 128 Mo ; rien sur le disque, rien dans les sauvegardes. Mémoire bornée à 768 Mo.
- **Ollama partagé** : une seule requête à la fois sur le serveur. Une question de visiteur peut faire attendre tes propres apps (et inversement) ; baisse le quota, ou arrête la démo (`sudo docker compose stop datamind-demo`), si c'est gênant.

## IA du serveur (Ollama)

Un seul Ollama tourne sur le VPS (service `ollama`, `127.0.0.1:11434`) et sert toutes les apps hébergées : Nexus, Viz, Convert, DataMind (et sa démo publique), Projets, Wiki, Formulaire, Trésorerie, Savoir, Ciné, et l'assistant de **Tab**, qui n'utilise plus l'Ollama de ton Mac. Cuisine, Dates et Suivi ne sont pas concernées.

- **Un seul modèle pour tout le monde** (`OLLAMA_MODEL` dans `.env`), choisi à l'installation selon la mémoire du serveur : `llama3.1:8b` à partir de 10 Go, `llama3.2:3b` à partir de 5 Go, `llama3.2:1b` en dessous. Il est téléchargé une fois (2 à 5 Go) et reste en mémoire 30 minutes après la dernière demande.
- **Lent sans carte graphique** : une réponse prend de quelques secondes à quelques minutes. Les délais des apps sont réglés à 10 minutes.
- **Tab** joint l'IA par `https://tab.<domaine>/ollama/`, derrière la connexion du portail. Seules les routes de conversation passent : personne ne peut télécharger ou supprimer de modèle depuis Internet.
- **Wiki** (« Rédiger avec l'IA ») et **Formulaire** (« Créer avec l'IA ») proposent un brouillon que tu relis avant d'enregistrer.
- **Claude reste possible** dans Nexus, Viz, Convert et DataMind avec `ANTHROPIC_API_KEY` (jamais dans la démo publique de DataMind) ; sans clé, Nexus utilise l'IA du serveur.

## À savoir

- **Tab dans le navigateur garde ses données dans le navigateur.** L'interface web de Tab enregistre tes tables dans IndexedDB, sur l'appareil qui l'ouvre. Ce que Nexus écrit dans Tab passe par le serveur MCP, qui travaille sur les fichiers de `data/atelier_tab/`. Les deux ne se voient pas. Pour les réunir, il faudrait brancher l'adaptateur `restAdapter` déjà présent dans Tab sur un petit service de stockage côté VPS.
- **Convert sur le serveur** : « Envoyer dans Atelier Tab » écrit dans `data/atelier_tab/` (les fichiers du MCP de Tab, que Nexus voit), pas dans le Tab de ton navigateur. Depuis le navigateur, utilise plutôt l'export (CSV français, Excel). L'OCR (Tesseract, français + anglais) est inclus dans l'image et tourne sur le VPS.
- **Envoi Tab → Projets depuis le navigateur.** L'export par défaut vise `http://127.0.0.1:3000`, c'est-à-dire ton propre ordinateur. Sur le VPS, depuis Tab : passe en mode en ligne, mets `https://projets.atelier.mondomaine.fr/api/imports/atelier-tab` comme adresse. La route d'import n'autorise en CORS que les origines locales : tant que Projets ne l'ouvre pas à `https://tab.…`, cet envoi précis reste bloqué. Les workflows Nexus Tab → Projets, eux, fonctionnent (ils passent par le serveur).
- **Claude par abonnement (CLI).** Les images utilisent la clé API Anthropic (`CLAUDE_MODE=api`). Le mode CLI de Viz et Nexus n'est pas installé dans les conteneurs.
- **Analyse Git de Projets.** Elle lit un dépôt local (`localRepoPath`) : sur le VPS, il faudrait que le dépôt soit cloné dans le conteneur. Le reste de Projets fonctionne normalement.
- **Nexus et les autres ateliers.** Nexus joint Trésorerie, Savoir et Ciné en `127.0.0.1` (adresses fixées dans `docker-compose.yml`). Ils n'ont pas encore de manifeste `atelier-node/1` : leurs agents fonctionnent, mais ils n'apparaissent pas comme étapes dans l'éditeur de workflows.
- **Trésorerie et données financières.** Nexus verrouille ses agents financiers sur Ollama, qui tourne sur le serveur : rien ne part chez un tiers. Garde aussi Ollama comme moteur dans les paramètres de Trésorerie.
- **Suivi → Trésorerie.** La synchro de Suivi (script `launchd` sur le Mac) vise encore `http://127.0.0.1:5050` sur ton Mac. Si tu n'utilises plus que la Trésorerie du VPS, cette synchro est à déplacer sur le VPS.
- **Ciné et l'espace disque.** Les vidéos occupent vite des dizaines de Go : vérifie la place libre avec `df -h` avant de les copier.
- **Cuisine, Dates et Suivi** restent sur Vercel uniquement : leurs notifications iPhone, liens par e-mail et apps installées sur l'écran d'accueil dépendent de leur adresse Vercel. Le portail se contente de les ouvrir dans un onglet.
- **Wiki et Nexus.** Le Wiki est un nœud `atelier-node/1` (manifeste sur `http://127.0.0.1:3200/api/atelier/manifest` : chercher, lire, créer, compléter des pages). Nexus ne le connaît pas encore : il faudra lui ajouter `WIKI_BASE_URL=http://127.0.0.1:3200/api` pour que ses workflows s'en servent.

- **Formulaire et Nexus / Viz.** Formulaire est aussi un nœud `atelier-node/1` (`http://127.0.0.1:3300/api/atelier/manifest` : lire les formulaires et les réponses, envoyer une réponse) et publie ses réponses au format des jeux de données d'Atelier Projets (`/api/exports/datasets`), que Viz sait lire.

## Dépannage

| Symptôme | Piste |
|---|---|
| Le navigateur signale un certificat invalide | Le DNS ne pointe pas encore vers le VPS. Vérifie avec `dig +short viz.atelier.mondomaine.fr`, puis `sudo docker compose logs caddy`. |
| « 403 FORBIDDEN_HOST » dans Projets ou Viz | `ATELIER_DOMAIN` dans `.env` ne correspond pas à l'adresse tapée. Corrige-le, puis `sudo docker compose up -d --build`. |
| Une tuile du portail reste « Hors ligne » | `sudo docker compose logs -f <app>` : souvent une migration ou une variable manquante. |
| La construction s'arrête sans message (« Killed ») | Manque de mémoire : vérifie que le swap est actif (`swapon --show`). |
| Nexus : « Migrations non appliquées » | PostgreSQL pas prêt au premier démarrage. `sudo docker compose restart nexus-backend`. |
