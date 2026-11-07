---
name: Suite Atelier
description: Système de design commun des apps Atelier, servi par le portail (/atelier.css, /atelier-icons.svg, /fonts/*.woff2).
colors:
  accent: "#5b5bd6"
  accent-ink: "#ffffff"
  accent-soft: "color-mix(in oklab, #5b5bd6 14%, transparent)"
  bg: "#f8f4ec"
  bg-side: "#f1ebdf"
  surface: "#fffdf8"
  hover: "#efe8db"
  selected: "#e6ddcc"
  line: "#e4dac8"
  line-strong: "#cfc2a9"
  ink: "#1f1b16"
  ink-2: "#3c362e"
  muted: "#5f574b"
  faint: "#6b6255"
  up: "#14743f"
  up-dot: "#209855"
  partial: "#9a5700"
  partial-dot: "#b37a15"
  down: "#b92b27"
  down-dot: "#e5484d"
  mark-bg: "#1f1b16"
  dark-accent: "#8285ff"
  dark-accent-ink: "#0b1220"
  dark-bg: "#0b1220"
  dark-bg-side: "#0e1626"
  dark-surface: "#121b2d"
  dark-hover: "#172238"
  dark-selected: "#1f2c46"
  dark-line: "#1f2a40"
  dark-line-strong: "#2d3b57"
  dark-ink: "#e6eaf2"
  dark-ink-2: "#ccd3df"
  dark-muted: "#a3aec2"
  dark-faint: "#8b97ad"
  dark-up: "#4cc38a"
  dark-partial: "#f0b44c"
  dark-down: "#ff6b6b"
  dark-mark-bg: "#1f2c46"
  app-nexus: "#c84f00"
  app-viz: "#996c00"
  app-tab: "#1c8742"
  app-projets: "#568100"
  app-wiki: "#007cbb"
  app-formulaire: "#008478"
  app-tresorerie: "#3c72da"
  app-savoir: "#a853c1"
  app-cine: "#cd3d83"
  app-convert: "#9d6d1c"
  app-portfolio: "#4a5468"
  app-ops: "#895bd5"
  app-mission: "#b55d00"
  app-datamind: "#6967e1"
  app-suivi: "#15aabf"
  app-dates: "#db373a"
  app-cuisine: "#9b84dc"
typography:
  headline:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.45
    letterSpacing: "-0.012em"
    fontFeature: "\"cv11\", \"ss03\""
  title:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.45
    fontFeature: "\"cv11\", \"ss03\""
  title-sm:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.45
    fontFeature: "\"cv11\", \"ss03\""
  body:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.45
    fontFeature: "\"cv11\", \"ss03\""
  label:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1
    fontFeature: "\"cv11\", \"ss03\""
  label-sm:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1
    fontFeature: "\"cv11\", \"ss03\""
  meta:
    fontFamily: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "11.5px"
    fontWeight: 500
    lineHeight: 1
    fontFeature: "\"cv11\", \"ss03\", \"tnum\""
rounded:
  xs: "4px"
  sm: "5px"
  md: "7px"
  lg: "10px"
  xl: "12px"
spacing:
  s1: "4px"
  s2: "8px"
  s3: "12px"
  s4: "16px"
  s5: "20px"
  s6: "24px"
components:
  button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0 12px"
    height: "30px"
  button-hover:
    backgroundColor: "{colors.hover}"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0 12px"
    height: "30px"
  button-primary-lg:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-ink}"
    typography: "{typography.title-sm}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "38px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.muted}"
    rounded: "{rounded.md}"
    size: "30px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.title-sm}"
    rounded: "{rounded.md}"
    padding: "0 12px"
    height: "36px"
  nav-item:
    backgroundColor: "transparent"
    textColor: "{colors.ink-2}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0 8px"
    height: "30px"
  nav-item-current:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.ink}"
  segmented:
    backgroundColor: "{colors.hover}"
    rounded: "{rounded.md}"
    padding: "2px"
  segmented-pressed:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.sm}"
    height: "24px"
  kbd:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.muted}"
    rounded: "{rounded.xs}"
    padding: "0 5px"
    height: "18px"
  list-row:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    padding: "0 20px"
    height: "40px"
  list-row-hover:
    backgroundColor: "{colors.hover}"
  list-row-selected:
    backgroundColor: "{colors.accent-soft}"
  app-icon:
    rounded: "{rounded.sm}"
    size: "20px"
  app-icon-lg:
    size: "44px"
  kpi-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    padding: "14px 16px"
  error:
    textColor: "{colors.down}"
    rounded: "{rounded.md}"
    padding: "10px 12px"
---

# Design System: Suite Atelier

## Overview

**Creative North Star: "L'établi rangé"**

La Suite Atelier est un outil, pas une vitrine. Chaque écran se lit comme un établi bien rangé : une barre latérale où l'on choisit, une zone principale en lignes denses où l'on agit, et le clavier qui va plus vite que la souris. Le niveau de finition visé est celui de Linear, joué franc : crème en clair, bleu nuit en sombre, Inter à 13 px, traits fins, aucun ornement qui ne porte pas d'information.

La couleur est rare et toujours fonctionnelle. Un seul accent indigo pour la sélection, le focus et l'action principale ; les couleurs d'état n'apparaissent que lorsqu'un service ne va pas bien ; la seule couleur « décorative » admise est celle de chaque app, enfermée dans son icône. La profondeur vient des tons (barre latérale un cran plus sombre que le fond) et des filets d'un pixel, presque jamais des ombres.

Le système est un fichier unique, `atelier.css`, servi par le portail avec ses icônes (`atelier-icons.svg`) et ses fontes (`/fonts/*.woff2`), en CORS ouvert : chaque app de la suite, quelle que soit sa techno, le lie ou le recopie tel quel, sans outillage. Clair et sombre sont deux jeux de jetons sur `html[data-theme]`, et le choix de l'utilisateur suit d'une app à l'autre.

**Key Characteristics:**
- Coquille barre latérale 232 px + barre haute 44 px + lignes de 40 px.
- Inter variable auto-hébergée, base 13 px, chiffres tabulaires pour toute mesure.
- Un accent indigo, des états vert/ambre/rouge seulement hors nominal.
- Chaque app identifiée par sa couleur `--app` et son glyphe `app-<id>` dans un carré arrondi en dégradé.
- Thème Système/Clair/Sombre partagé par cookie entre tous les sous-domaines.
- Plat par défaut : tons et filets plutôt qu'ombres.

## Colors

Une structure crème en clair et bleu nuit en sombre (mêmes valeurs que `--atelier-*` de la marque commune, §2 et §3 ; Dates, Suivi et Cuisine gardent leurs fonds teintés, §3 bis), un indigo pour agir, trois couleurs d'état qui se taisent quand tout va bien, et une palette d'apps à contraste homogène (chacune ≥ 4,5:1 avec du blanc).

### Primary
- **Indigo d'atelier** (`accent`, clair / `dark-accent`, sombre) : sélection, anneau de focus (2 px, décalage 2 px), bouton principal, case cochée, flèche de la ligne sélectionnée, marque « Dernière ». Texte posé dessus : `accent-ink` (blanc en clair, quasi-noir en sombre).
- **Voile indigo** (`accent-soft`, l'accent à 14 % dans oklab) : fond de la ligne ou tuile sélectionnée, halo de 3 px des champs en focus. La sélection de texte prend l'accent à 30 %.

### Secondary
- **Couleurs d'app** (`app-<id>`, chacune ≥ 4,5:1 avec du texte blanc) : la source normative est `Atelier_Projets/design-system/brand/atelier-brand.css` (`--atelier-sig-<id>`), recopiée dans `portail/server.mjs` (HOSTED, SITES, ONLINE). Sur le portail, elles ne colorent que l'icône d'app, jamais du texte ni un fond de ligne ; dans chaque app, la signature devient l'accent (bouton principal, sélection, focus). PRODUCT.md confirme qu'elles ne sont pas figées.

### Tertiary
- **États** : vert `up`/`up-dot`, ambre `partial`/`partial-dot`, rouge `down`/`down-dot`. La variante `-dot` sert à la pastille de 8 px, la variante pleine au texte (contraste lisible). En sombre, une seule valeur par état (`dark-up`, `dark-partial`, `dark-down`) sert aux deux.

### Neutral
- **Fond d'atelier** (`bg`) : fond de la zone principale et de la page de connexion.
- **Fond de barre** (`bg-side`) : barre latérale et en-têtes de groupe collants, un cran sous le fond.
- **Surface** (`surface`) : boutons, champs, touches, segment pressé.
- **Survol** (`hover`) et **Sélection neutre** (`selected`) : survol de tout élément interactif ; élément de navigation courant, bouton pressé, avatar.
- **Filet** (`line`) et **Filet appuyé** (`line-strong`) : séparateurs de lignes, bords de barres ; bords de boutons et champs, ascenseurs.
- **Encre** (`ink`), **Encre seconde** (`ink-2`), **Atténué** (`muted`), **Discret** (`faint`) : titres et noms ; libellés de navigation et de champ ; rôles, latences, texte secondaire ; compteurs, touches, numéros, icônes de navigation au repos.
- **Fond de marque** (`mark-bg`) : carré de la marque Atelier (quatre carrés orange, jaune, vert, indigo).

### Named Rules
**La règle du témoin muet.** Un service en bonne santé n'affiche que sa latence (« 31 ms », ou « statique »), sans pastille ni mot ni couleur. Ambre « Démarrage partiel », rouge « Hors ligne », cercle vide « Vérification… » : la couleur d'état n'existe que pour ce qui demande l'attention. Le vert ne sert qu'au résumé global quand tout répond.

**La règle de l'accent unique.** L'indigo signifie « ici, maintenant » : sélection, focus, action principale. Il n'habille ni titres, ni fonds de section, ni illustrations. Une app qui adopte un accent propre (permis par PRODUCT.md) redéfinit `--accent` dans les deux thèmes ; elle n'ajoute pas une seconde couleur d'action.

**La règle de l'app par sa couleur.** Une app se reconnaît à deux choses, toujours ensemble : sa couleur `--app` et son glyphe `app-<id>` dans l'icône carrée en dégradé. Pas de logo bitmap, pas de couleur d'app hors de l'icône.

## Typography

**Display Font:** aucune ; la suite n'a pas de police d'affichage.
**Body Font:** Inter variable (100 à 900), auto-hébergée en `/fonts/inter-latin-wght-normal.woff2` et `inter-latin-ext-wght-normal.woff2`, préchargée, `font-display: swap` (repli ui-sans-serif, system-ui, -apple-system, Segoe UI).
**Label/Mono Font:** aucune en usage ; `--mono` est déclaré mais aucune surface livrée ne l'emploie.

**Character:** une seule famille, réglée fin : variantes `cv11` et `ss03` d'Inter activées partout, lissage antialiasé, hiérarchie portée par la graisse (400 / 500 / 600) plus que par la taille. Les écarts de taille sont petits (11.5 à 20 px) parce que l'écran est un outil dense.

### Hierarchy
- **Headline** (600, 20 px, -0.012em) : titre d'une page autonome, comme « Connexion à la Suite Atelier ».
- **Title** (600, 15 px) : titre d'un état vide.
- **Title-sm** (500 à 600, 14 px) : nom de l'espace de travail (600), nom d'app en tuile, texte saisi dans un champ, bouton large, chapô de connexion (400, `muted`).
- **Body** (400, 13 px, 1.45) : texte courant, rôles des apps, notes des en-têtes de groupe. Le titre de la barre haute est un Body en 600.
- **Label** (500, 13 px, interligne 1) : boutons, éléments de navigation, noms d'app en liste, libellés de champ.
- **Label-sm** (400 à 500, 12 px) : états, segmenté, case à cocher, santé globale, latences, pied de page.
- **Meta** (500, 11.5 px, chiffres tabulaires) : compteurs, numéros de raccourci, intitulé de section de navigation (« Groupes », en casse de phrase). Les touches `.at-kbd` sont à 11 px.

### Named Rules
**La règle des chiffres alignés.** Toute mesure (latence, compteur, heure, « 12 sur 14 ») est en chiffres tabulaires.

**La règle de la casse de phrase.** Pas de capitales ni d'espacement élargi : intitulés, boutons et sections sont en casse de phrase, en français, au tutoiement.

## Layout

L'espace se pense en coquille d'app : une grille à deux colonnes, barre latérale fixe de 232 px (`--side-w`) et zone principale fluide. La barre latérale est collante sur toute la hauteur, défile seule, et porte de haut en bas la marque et le nom, la recherche (⌘K), la navigation, puis en pied le sélecteur de thème et le compte. La zone principale commence par une barre haute collante de 44 px (`--top-h`), translucide (fond à 88 %, flou 10 px, saturation 1.4), puis des en-têtes de groupe collants juste dessous, puis des lignes de 40 px (`--row-h`) séparées par un filet.

Le rythme suit un pas de 4 px (4, 8, 12, 16, 20, 24). Les gouttières horizontales de la zone principale sont de 20 px ; la barre latérale a 12 px en haut et 8 px sur les côtés ; les éléments de navigation sont espacés de 1 px. La densité est assumée : sur Mac, une vingtaine d'apps tiennent dans le premier écran.

Les lignes de liste sont des grilles dont chaque surface fixe les colonnes (au portail : touche, icône, nom, rôle, état, latence, flèche). Une vue alternative en tuiles (`minmax(156px, 1fr)`, écart 8 px) reprend les mêmes éléments.

Sous 760 px (règle aujourd'hui écrite dans la page du portail, pas dans `atelier.css`), la coquille passe en une colonne : la barre latérale devient un bandeau en haut, la navigation une rangée défilante de pastilles, les lignes montent à 52 px avec icône de 28 px, nom et rôle empilés, et la base typographique passe à 14 px. Les tuiles passent à deux colonnes.

## Elevation & Depth

Le système est plat par défaut. La profondeur se lit par paliers de ton (`bg-side` sous `bg`, `surface` au-dessus) et par des filets de 1 px, jamais par des ombres portées sur des surfaces au repos. Les seules ombres livrées sont des micro-ombres de matière : le segment pressé, le relief intérieur de l'icône d'app, et le halo de focus des champs. Une ombre de surgissement (`--shadow-pop`) et un panneau (`.at-panel`) sont déclarés pour les dialogues mais aucune surface livrée ne les exerce encore ; la page de connexion est posée à plat sur le fond.

### Shadow Vocabulary
- **Segment pressé** (`box-shadow: 0 1px 2px rgb(40 30 15 / 0.05), 0 0 0 1px var(--line)`) : l'option active d'un contrôle segmenté.
- **Relief d'icône** (`box-shadow: inset 0 0 0 0.5px rgb(0 0 0 / 0.14), inset 0 1px 0 rgb(255 255 255 / 0.22)`) : bord et reflet de l'icône d'app.
- **Halo de focus** (`box-shadow: 0 0 0 3px var(--accent-soft)`) : champ ou recherche en focus, avec bord passé à l'accent.
- **Surgissement** (`box-shadow: 0 1px 2px rgb(40 30 15 / 0.07), 0 8px 24px -8px rgb(40 30 15 / 0.2)` en clair ; `0 1px 2px rgb(0 0 0 / 0.45), 0 12px 32px -10px rgb(2 6 18 / 0.75)` en sombre, comme `--atelier-glow-strong`) : réservé aux panneaux flottants et dialogues, provisoire tant qu'aucun ne l'a exercé.

### Named Rules
**La règle du plat au repos.** Une surface au repos n'a pas d'ombre. Seul ce qui flotte réellement au-dessus du contenu (dialogue, menu) a droit au surgissement.

## Shapes

Des coins doucement arrondis, sur une échelle courte : 4 px pour les touches et cases, 5 px pour les petites icônes d'app et les options de segmenté, 7 px pour boutons, champs et éléments de navigation, 10 px pour tuiles et panneaux, 12 px pour les cartes de chiffres (`--atelier-radius-xl`). L'icône d'app suit sa taille (5 px à 20 px, 7 px à 28 px, 11 px à 44 px). Les lignes de liste n'ont pas de coins : elles vont d'un bord à l'autre, séparées par des filets. Le cercle n'est admis que pour les pastilles d'état et l'avatar. Les touches de clavier ont un bord inférieur de 2 px, comme une vraie touche.

Les icônes d'interface sont des traits sur une grille de 24, dérivés de Lucide (licence ISC), rendus à 16 px (14 px en version petite), trait 1.75, extrémités rondes, en `currentColor`, via le sprite `atelier-icons.svg` (`i-*`).

## Components

### Buttons
Sobres et précis : on les remarque quand on les cherche.
- **Shape:** coins de 7 px, hauteur 30 px (38 px en large), bord 1 px `line-strong`.
- **Primary:** fond indigo, texte `accent-ink`, sans bord ; au survol l'accent se mélange à 12 % d'encre. Un seul par écran.
- **Default:** fond `surface`, texte `ink` ; survol `hover`, appui `selected`, désactivé à 50 % d'opacité.
- **Ghost / Icon:** transparent, texte `muted`, devient `ink` sur `hover` ; en version icône, carré de 30 px.
- **Focus:** anneau indigo de 2 px décalé de 2 px, commun à tout élément focalisable.

### Inputs / Fields
- **Style:** hauteur 36 px, fond `surface`, bord 1 px `line-strong`, coins 7 px, texte 14 px, placeholder `faint`. Le libellé est au-dessus (13 px, 500, `ink-2`, écart 6 px).
- **Focus:** bord indigo et halo `accent-soft` de 3 px, sans contour natif.
- **Error:** bord `down` via `aria-invalid="true"` ; message au-dessus du formulaire dans un encadré rouge (texte `down`, fond rouge à 9 %, bord rouge à 30 %, coins 7 px), avec `role="alert"`.

### Navigation
- **Style:** éléments de 30 px, icône 16 px `faint` + libellé Label `ink-2` + compteur Meta poussé à droite.
- **States:** survol `hover`/`ink` ; courant (`aria-current="true"`) `selected` neutre avec icône en `ink`. La navigation n'utilise jamais l'accent : il est réservé à la sélection dans le contenu.
- **Sections:** intitulé Meta `faint` en casse de phrase.
- **Compteur d'alerte:** le compteur passe au rouge `down` quand il compte des incidents.
- **Mobile:** rangée défilante de pastilles bordées (rayon plein), sans icônes.

### Contrôles compacts
- **Segmenté:** rail `hover` de 2 px de marge, options de 24 px en Label-sm `muted` ; l'option pressée (`aria-pressed="true"`) passe sur `surface` avec la micro-ombre. Sert aux bascules de vue et au choix du thème (Système / Clair / Sombre, icônes moniteur, soleil, lune).
- **Case à cocher:** 14 px, coins 4 px, cochée en indigo avec coche `accent-ink`.
- **Touche:** 18 px de haut, Meta 11 px `muted`, bord inférieur de 2 px. Les légendes ⌘ ↵ ↑ ↓ sont du texte de touche, pas des icônes.

### Liste dense
- **Ligne:** 40 px minimum, gouttière 20 px, filet `line` en bas, survol `hover`.
- **Sélection:** fond `accent-soft` et flèche de fin qui passe à l'indigo en glissant de 3 px (200 ms, `cubic-bezier(0.16, 1, 0.3, 1)`). La sélection suit à la fois le clavier et la souris. En tuile, la sélection ajoute un bord indigo à 35 %.
- **En-tête de groupe:** collant sous la barre haute, fond `bg-side`, titre 600 `ink` + compteur + note `muted`.

### Cartes de chiffres (KPI)
Un chiffre clé (total, compteur, solde, synthèse) se pose dans une carte arrondie : composant `.atelier-kpi` de la marque commune (`__label` Label-sm `muted`, `__value` 24 px en 600 et chiffres tabulaires, `__note` Meta `faint`), fond `surface`, bord 1 px `line`, coins de 12 px, sans ombre. Plusieurs chiffres forment une rangée de cartes espacées de 8 px, jamais une bande découpée par des filets. Les tableaux et les listes restent des tableaux et des listes. Le portail n'a pas de carte de chiffres.

### État d'un service
Pastille de 8 px suivie d'un libellé Label-sm. `partial` : texte et pastille ambre ; `down` : texte rouge en 500 ; `unknown` : cercle vide `faint` ; `up` : pastille verte, réservée au résumé global ; `ext` : pas de pastille (les apps externes affichent « Vercel ↗ »).

### Icône d'app (signature)
Carré arrondi rempli d'un dégradé vertical de la couleur d'app (en haut 78 % de la couleur mêlée de blanc, en bas la couleur pure), avec relief intérieur, et le glyphe `app-<id>` du sprite en trait blanc (62 % de la taille, trait 2.1 ; 1.9 à 44 px). Tailles : 20 px en liste, 28 px en liste mobile, 44 px en tuile. Sans `--app`, l'icône retombe sur un gris neutre.

### Service tombé
Un seul traitement, partout dans la suite : sur l'élément porteur de `.is-down`, l'icône d'app passe à 85 % de niveaux de gris et 55 % d'opacité, et le nom passe en `muted`. L'état « Hors ligne » en rouge porte le message ; l'icône éteinte porte l'ambiance.

### Thème partagé
Le choix vit dans le cookie `atelier_theme` (`system`, `light` ou `dark`), posé sur `Domain=<ATELIER_DOMAIN>`, `Path=/`, un an, `SameSite=Lax` (et `Secure` en https), donc lu par le portail et tous les sous-domaines. Chaque page l'applique avant l'affichage par un petit script en ligne placé avant la feuille de style, qui pose `data-theme="light|dark"` (et `data-theme-pref`) sur `<html>` ; `system` suit `prefers-color-scheme`, y compris en direct. Toute app de la suite reprend ce script à l'identique et écrit le même cookie si elle propose le choix.

## Do's and Don'ts

### Do:
- **Do** lier ou recopier `atelier.css` et `atelier-icons.svg` tels quels, et précharger `/fonts/inter-latin-wght-normal.woff2`.
- **Do** appliquer le thème avant l'affichage avec le script du cookie `atelier_theme`, et écrire le cookie sur `Domain=<ATELIER_DOMAIN>`.
- **Do** identifier chaque app par `--app` et son glyphe `app-<id>` dans l'icône en dégradé, et ajouter le glyphe au sprite quand une app arrive.
- **Do** montrer la sélection par `accent-soft` et une flèche indigo, et le courant de navigation par `selected` neutre.
- **Do** laisser un service sain silencieux : latence seule, en chiffres tabulaires.
- **Do** réutiliser le traitement `.is-down` unique pour tout service tombé.
- **Do** tenir le pas de 4 px, les lignes de 40 px et la base de 13 px sur Mac.
- **Do** garder les deux thèmes en jetons : toute nouvelle couleur reçoit une valeur claire (sur crème) et une valeur sombre (sur bleu nuit) ; un fond fixe hors CSS (`theme-color`, fenêtre de bureau, e-mail) vaut `#f8f4ec` ou `#0b1220`.
- **Do** poser les chiffres clés dans des cartes `.atelier-kpi` arrondies (12 px), en rangée espacée.

### Don't:
- **Don't** construire une grille de tuiles illustrées ou de logos néon en guise d'accueil ; la vue en icônes reste une liste disposée en grille.
- **Don't** colorer un état nominal (pas de pastille verte, pas de « En ligne » par ligne).
- **Don't** utiliser l'indigo comme décor, ni la couleur d'une app hors de son icône.
- **Don't** inventer un autre traitement pour un service tombé, ni une autre clé de stockage du thème.
- **Don't** poser d'ombre sur une surface au repos.
- **Don't** employer de caractères ou d'emoji comme icônes : toute icône vient du sprite à trait ; seules les légendes de touches restent du texte.
- **Don't** écrire d'intitulés en capitales espacées ni de surtitres au-dessus des titres.
