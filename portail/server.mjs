// Portail de la suite Atelier : page de sélection des apps + connexion unique.
// Aucun paquet externe : Node 22 suffit.
//
// Rôles :
//   GET  /                 portail (sélection de l'app), réservé aux personnes connectées
//   GET  /connexion        formulaire de connexion        POST /connexion   vérifie et pose le cookie
//   POST /deconnexion      efface le cookie
//   GET  /auth/verify      appelé par Caddy (forward_auth) avant chaque requête vers une app
//   GET  /api/statut       état de chaque app, sondé côté serveur sur 127.0.0.1
//   GET  /sante            sonde de vie du portail (publique)

import { createServer } from 'node:http'
import { createHmac, timingSafeEqual, randomBytes, scrypt, scryptSync } from 'node:crypto'
import { promisify } from 'node:util'
import { readFile } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))

// ── Réglages ────────────────────────────────────────────────────────────────
const env = process.env
const DOMAIN = (env.ATELIER_DOMAIN || 'atelier.localhost').toLowerCase()
const SCHEME = env.SITE_SCHEME === 'http' ? 'http' : 'https'
const PORT = Number(env.PORTAL_PORT || 9000)
const HOST = env.PORTAL_BIND || '127.0.0.1'
const USER = env.PORTAL_USER || 'atelier'
const PASSWORD = env.PORTAL_PASSWORD || ''
const SECRET = env.SESSION_SECRET || ''
const SESSION_DAYS = Number(env.SESSION_DAYS || 30)
const COOKIE = 'atelier_session'

if (PASSWORD.length < 10) fail('PORTAL_PASSWORD doit faire au moins 10 caractères.')
if (SECRET.length < 32) fail('SESSION_SECRET doit faire au moins 32 caractères.')

// Le mot de passe n'est jamais comparé en clair : on compare deux empreintes de même longueur.
const salt = randomBytes(16)
const passwordDigest = scryptSync(PASSWORD, salt, 32)
// Pendant le service, l'empreinte se calcule hors du fil principal : une rafale de tentatives de connexion ne fait
// pas attendre /auth/verify, donc aucune app.
const digest = promisify(scrypt)

/**
 * Les apps du portail. `color` = signature de l'app (Atelier_Projets/design-system/brand/atelier-brand.css, --atelier-sig-<id>).
 * Hébergées sur le VPS : `sub` = sous-domaine, `probes` = adresses locales sondées par le serveur.
 * En ligne (Vercel + Supabase, leur propre connexion) : `external` = adresse ouverte dans un onglet.
 * Dates, Suivi et Cuisine sont des apps en ligne : le portail ouvre leur adresse Vercel.
 * Sites & tests (`group: 'sites'`) : simulations et maquettes hébergées sur le VPS, rangées dans leur propre section.
 */
const HOSTED = [
  {
    id: 'nexus', name: 'Nexus', role: 'Workflows et agents IA de la suite', color: '#c84f00', sub: 'nexus',
    probes: ['http://127.0.0.1:8100/health', 'http://127.0.0.1:3100/'],
  },
  {
    id: 'viz', name: 'Viz', role: 'BI : jeux de données, rapports, alertes', color: '#996c00', sub: 'viz',
    probes: ['http://127.0.0.1:8000/api/health'],
  },
  {
    id: 'tab', name: 'Tab', role: 'Tableur et base typée', color: '#1c8742', sub: 'tab',
    probes: [], // app statique servie par Caddy : toujours disponible si le portail l'est
  },
  {
    id: 'projets', name: 'Projets', role: 'Projets agiles, jalons, temps passé', color: '#568100', sub: 'projets',
    probes: ['http://127.0.0.1:3000/api/health'],
  },
  {
    id: 'wiki', name: 'Wiki', role: 'Pages, procédures et notes de la suite', color: '#007cbb', sub: 'wiki',
    probes: ['http://127.0.0.1:3200/api/health'],
  },
  {
    id: 'hub', name: 'Hub', role: 'Tout ce que la suite sait d’un projet', color: '#9a3e6c', sub: 'hub',
    probes: ['http://127.0.0.1:3700/api/health'],
  },
  {
    id: 'formulaire', name: 'Formulaire', role: 'Questionnaires, inscriptions, retours', color: '#008478', sub: 'formulaire',
    probes: ['http://127.0.0.1:3300/api/health'],
  },
  {
    id: 'tresorerie', name: 'Trésorerie', role: 'Comptes, budgets, objectifs', color: '#3c72da', sub: 'tresorerie',
    probes: ['http://127.0.0.1:5050/api/ping'],
  },
  {
    id: 'savoir', name: 'Savoir', role: 'Cours, fiches et révisions', color: '#a853c1', sub: 'savoir',
    probes: ['http://127.0.0.1:5051/api/stats'],
  },
  {
    id: 'cine', name: 'Ciné', role: 'Films et séries en streaming', color: '#cd3d83', sub: 'cine',
    probes: ['http://127.0.0.1:4000/api/health'],
  },
  {
    id: 'convert', name: 'Convert', role: 'Relevés et fichiers en tables pour Tab', color: '#9d6d1c', sub: 'convert',
    probes: ['http://127.0.0.1:8010/api/health'],
  },
].map((a) => ({ ...a, url: `${SCHEME}://${a.sub}.${DOMAIN}/` }))

// Vitrine pro : ce que François montre aux recruteurs et aux clients. Tout y est PUBLIC (sans connexion)
// et sans IA payante (la démo de DataMind n'a que l'IA du serveur). `share` = lien public à copier depuis le portail.
// Le Portfolio et ses démos peuvent avoir une adresse publique propre (PORTFOLIO_PUBLIC_URL, ex. le relais
// Netlify https://francois-pichon.netlify.app) ; sinon portfolio.<domaine>.
const PORTFOLIO_BASE = (env.PORTFOLIO_PUBLIC_URL || `${SCHEME}://portfolio.${DOMAIN}`).replace(/\/$/, '')
const PORTFOLIO_PROBE = ['http://127.0.0.1:8787/api/health']
const VITRINE = [
  {
    id: 'portfolio', name: 'Portfolio', role: 'CV, projets d’économétrie, contact', color: '#4a5468',
    path: '/', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-immobilier', icon: 'demo-immobilier', name: 'Observatoire immobilier', role: 'Démo · prix au m² DVF, carte, modèle de prix',
    color: '#4a5468', path: '/demos/observatoire-immobilier', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-ecommerce', icon: 'demo-ecommerce', name: 'E-commerce temps réel', role: 'Démo · KPI en direct, détection d’anomalies',
    color: '#4a5468', path: '/demos/ecommerce-temps-reel', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-ab', icon: 'demo-ab', name: 'Labo A/B et causal', role: 'Démo · puissance, significativité, diff-in-diff',
    color: '#4a5468', path: '/demos/labo-ab-causal', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-prevision', icon: 'demo-prevision', name: 'Prévision de ventes', role: 'Démo · CSV → prévision avec intervalles',
    color: '#4a5468', path: '/demos/prevision-ventes', probes: PORTFOLIO_PROBE,
  },  {
    id: 'demo-sql', icon: 'demo-sql', name: 'SQL Lab', role: 'Démo · base SQLite dans le navigateur, 9 défis corrigés',
    color: '#4a5468', path: '/demos/sql-lab', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-qualite', icon: 'demo-qualite', name: 'Qualité des données', role: 'Démo · profil d’un CSV, score et nettoyage',
    color: '#4a5468', path: '/demos/qualite-donnees', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-dashboard', icon: 'demo-dashboard', name: 'Tableau de bord', role: 'Démo · KPI filtrables, cohortes de fidélité',
    color: '#4a5468', path: '/demos/tableau-de-bord', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-modelisation', icon: 'demo-modelisation', name: 'Modélisation de données', role: 'Démo · schéma relationnel, normalisation, DDL',
    color: '#4a5468', path: '/demos/modelisation-donnees', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-segmentation', icon: 'demo-segmentation', name: 'Segmentation clients', role: 'Démo · RFM et k-means, portrait des segments',
    color: '#4a5468', path: '/demos/segmentation-clients', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-elasticite', icon: 'demo-elasticite', name: 'Élasticité-prix', role: 'Démo · régression log-log, prix optimal',
    color: '#4a5468', path: '/demos/elasticite-prix', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-churn', icon: 'demo-churn', name: 'Score de churn', role: 'Démo · régression logistique, ROC, seuil au coût',
    color: '#4a5468', path: '/demos/score-churn', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-regression', icon: 'demo-regression', name: 'Labo de régression', role: 'Démo · MCO, erreurs robustes, diagnostics',
    color: '#4a5468', path: '/demos/labo-regression', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-attribution', icon: 'demo-attribution', name: 'Attribution marketing', role: 'Démo · heuristiques, Markov, Shapley',
    color: '#4a5468', path: '/demos/attribution-marketing', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-pipeline', icon: 'demo-pipeline', name: 'Pipeline de données', role: 'Démo · DAG SQL, tests de données, lignage',
    color: '#4a5468', path: '/demos/pipeline-donnees', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-impact', icon: 'demo-impact', name: 'Impact sans groupe témoin', role: 'Démo · contrôle synthétique, placebos',
    color: '#4a5468', path: '/demos/impact-sans-temoin', probes: PORTFOLIO_PROBE,
  },
  {
    id: 'demo-survie', icon: 'demo-survie', name: 'Durée de vie client', role: 'Démo · Kaplan-Meier, Cox, valeur vie',
    color: '#4a5468', path: '/demos/duree-vie-client', probes: PORTFOLIO_PROBE,
  },
]
  .map((a) => ({ ...a, url: `${PORTFOLIO_BASE}${a.path}` }))
  .concat([
    {
      // DataMind en direct : service datamind-demo (même image que la tuile privée de Sites & tests), en mode démo :
      // jeux d'exemple, aucune écriture, IA du serveur limitée par visiteur, Claude coupé. Public par Caddy.
      id: 'demo-datamind', icon: 'datamind', name: 'DataMind', role: 'Démo en direct · agent d’analyse, jeux d’exemple',
      color: '#6967e1', url: `${SCHEME}://demo-datamind.${DOMAIN}/`, probes: ['http://127.0.0.1:3601/api/health'],
    },
    {
      // Ops Lab : simulation qui tourne dans le navigateur, rendue publique par Caddy.
      id: 'ops', name: 'Ops Lab', role: 'Démo · TMS simulé, piloté par un agent IA', color: '#895bd5',
      url: `${SCHEME}://ops.${DOMAIN}/`, probes: ['http://127.0.0.1:3400/api/health'],
    },
  ])
  .map(({ path, ...a }) => ({ ...a, group: 'vitrine', public: true, share: a.url }))

// Sites & tests : hébergés sur le VPS, derrière la connexion, dans une section à part du portail.
// Pour en ajouter un : une entrée ici (+ icône <symbol id="app-<id>"> dans public/atelier-icons.svg), un bloc Caddy, un service Docker.
const SITES = [
  {
    id: 'mission', name: 'Mission', role: 'Prospects, devis, factures Malt, relances', color: '#b55d00', sub: 'mission',
    probes: ['http://127.0.0.1:3500/api/health'],
  },
  {
    id: 'datamind', name: 'DataMind', role: 'Agent IA d’analyse de données', color: '#6967e1', sub: 'datamind',
    probes: ['http://127.0.0.1:3600/api/health'],
  },
].map((a) => ({ ...a, group: 'sites', url: `${SCHEME}://${a.sub}.${DOMAIN}/` }))

const ONLINE = [
  {
    id: 'suivi', name: 'Suivi', role: 'Tâches du jour, habitudes, dépenses', color: '#15aabf',
    url: env.SUIVI_URL || 'https://atelier-suivi-bay.vercel.app',
  },
  {
    id: 'dates', name: 'Dates', role: 'Notre petit monde, à deux', color: '#db373a',
    url: env.DATES_URL || 'https://atelier-dates.vercel.app',
  },
  {
    id: 'cuisine', name: 'Cuisine', role: 'Garde-manger, recettes, tickets', color: '#9b84dc',
    url: env.CUISINE_URL || 'https://atelier-cuisine-iota.vercel.app',
  },
].map((a) => ({ ...a, external: true, probes: [] }))

const APPS = [...HOSTED, ...VITRINE, ...SITES, ...ONLINE]
const PROBED = [...HOSTED, ...VITRINE, ...SITES]

// ── Session signée (HMAC-SHA256), sans stockage côté serveur ────────────────
const b64 = (buf) => Buffer.from(buf).toString('base64url')
// La clé de signature dépend du secret ET du mot de passe : changer PORTAL_PASSWORD (ou PORTAL_USER) rend
// invalides toutes les sessions déjà ouvertes, sur tous les appareils.
const KEY = createHmac('sha256', SECRET).update(`session:${USER}:${PASSWORD}`).digest()
const sign = (data) => createHmac('sha256', KEY).update(data).digest('base64url')

function makeToken(user) {
  const payload = b64(JSON.stringify({ u: user, exp: Date.now() + SESSION_DAYS * 864e5 }))
  return `${payload}.${sign(payload)}`
}

function readToken(token) {
  if (!token || !token.includes('.')) return null
  const [payload, mac] = token.split('.')
  const expected = Buffer.from(sign(payload))
  const given = Buffer.from(mac || '')
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) return null
  try {
    const data = JSON.parse(Buffer.from(payload, 'base64url').toString())
    return data.exp > Date.now() ? data : null
  } catch {
    return null
  }
}

/**
 * La session portée par la requête, ou null. Les valeurs ne sont pas décodées : le jeton n'en a pas besoin, et un
 * cookie mal encodé posé par une app (« prefs=100% ») ne doit pas faire échouer forward_auth pour toute cette app.
 * Tous les cookies du nom sont essayés : un ancien exemplaire resté dans le navigateur ne masque pas le bon.
 */
function session(req) {
  for (const part of (req.headers.cookie || '').split(';')) {
    const i = part.indexOf('=')
    if (i < 0 || part.slice(0, i).trim() !== COOKIE) continue
    const data = readToken(part.slice(i + 1).trim())
    if (data) return data
  }
  return null
}

function sessionCookie(value, maxAge) {
  // Domain=<domaine> : le cookie vaut pour le portail ET tous ses sous-domaines (viz., tab., …)
  const parts = [`${COOKIE}=${value}`, `Domain=${DOMAIN}`, 'Path=/', 'HttpOnly', 'SameSite=Lax', `Max-Age=${maxAge}`]
  if (SCHEME === 'https') parts.push('Secure')
  return parts.join('; ')
}

/** N'accepte qu'un retour vers le portail ou l'un de ses sous-domaines (pas de redirection ouverte). */
function safeReturn(raw) {
  try {
    const u = new URL(raw)
    const host = u.hostname.toLowerCase()
    if (u.protocol === `${SCHEME}:` && (host === DOMAIN || host.endsWith(`.${DOMAIN}`))) return u.href
  } catch {}
  return `${SCHEME}://${DOMAIN}/`
}

/**
 * Les formulaires du portail (connexion, déconnexion) ne s'envoient que depuis le portail : le navigateur annonce
 * d'où part chaque POST (en-tête Origin). Sans cet en-tête (curl, script), la demande ne vient pas d'une page web.
 */
function fromPortal(req) {
  const origin = req.headers.origin
  if (origin === undefined) return true
  try {
    return new URL(origin).host === DOMAIN
  } catch {
    return false // « null » (page isolée, redirection d'un autre site) ou valeur illisible
  }
}

// ── Limite d'essais de connexion : 8 essais ratés par adresse sur 15 min ────
const WINDOW = 15 * 60e3
const MAX_ATTEMPTS = 8
const attempts = new Map()
const recent = (key, now = Date.now()) => (attempts.get(key) || []).filter((t) => now - t < WINDOW)

/**
 * Ce qui compte pour la limite : l'adresse IPv4, ou le préfixe /64 d'une adresse IPv6. Un abonné IPv6 dispose d'un
 * /64 entier : compter par adresse lui laisserait autant d'essais qu'il veut.
 */
function rateKey(ip = '') {
  const v4 = ip.match(/^(?:::ffff:)?(\d+\.\d+\.\d+\.\d+)$/i)
  if (v4) return v4[1]
  if (!ip.includes(':')) return ip
  const [head, tail] = ip.split('%')[0].toLowerCase().split('::')
  const start = head ? head.split(':') : []
  const end = tail ? tail.split(':') : []
  const groups = tail === undefined ? start : [...start, ...Array(Math.max(8 - start.length - end.length, 0)).fill('0'), ...end]
  return `${groups.slice(0, 4).map((g) => (parseInt(g, 16) || 0).toString(16)).join(':')}::/64`
}

/** Secondes à attendre avant le prochain essai (0 = essai permis). */
function waitSeconds(key, now = Date.now()) {
  const list = recent(key, now)
  // Une adresse sans essai raté récent ne reste pas en mémoire.
  if (list.length) attempts.set(key, list)
  else attempts.delete(key)
  return list.length >= MAX_ATTEMPTS ? Math.ceil((list[list.length - MAX_ATTEMPTS] + WINDOW - now) / 1000) : 0
}
// Les adresses qui ne reviennent jamais sont oubliées au bout d'un quart d'heure (table bornée sous une attaque répartie).
setInterval(() => {
  const now = Date.now()
  for (const key of attempts.keys()) if (!recent(key, now).length) attempts.delete(key)
}, WINDOW).unref()
const noteAttempt = (key) => attempts.set(key, [...(attempts.get(key) || []), Date.now()])

// ── Sondes d'état ───────────────────────────────────────────────────────────
async function probe(url) {
  const t0 = performance.now()
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(2500), redirect: 'manual' })
    return { ok: res.status < 500, ms: Math.round(performance.now() - t0) }
  } catch {
    return { ok: false, ms: null }
  }
}

async function statuses() {
  // Plusieurs entrées partagent une même sonde (le Portfolio et ses démos) : une seule requête par adresse.
  const once = new Map()
  const probeOnce = (url) => {
    if (!once.has(url)) once.set(url, probe(url))
    return once.get(url)
  }
  return Promise.all(
    PROBED.map(async (a) => {
      if (!a.probes.length) return { id: a.id, state: 'up', ms: null }
      const results = await Promise.all(a.probes.map(probeOnce))
      const up = results.filter((r) => r.ok).length
      const state = up === results.length ? 'up' : up === 0 ? 'down' : 'partial'
      const ms = results.every((r) => r.ms != null) ? Math.max(...results.map((r) => r.ms)) : null
      return { id: a.id, state, ms }
    }),
  )
}

// ── Fichiers du système de design ──────────────────────────────────────────
const ASSETS = {
  '/atelier.css': { file: 'atelier.css', type: 'text/css; charset=utf-8' },
  '/atelier-icons.svg': { file: 'atelier-icons.svg', type: 'image/svg+xml' },
}

// ── Pages ───────────────────────────────────────────────────────────────────
const pages = {}
async function page(name) {
  if (!pages[name] || env.PORTAL_DEV) pages[name] = await readFile(join(here, 'public', name), 'utf8')
  return pages[name]
}

/**
 * Politique de sécurité des deux pages : seuls leurs propres scripts s'exécutent (jeton à usage unique, posé sur le
 * modèle avant qu'aucune donnée n'y soit insérée), et la page ne charge ni n'appelle rien hors du portail.
 */
function protect(template) {
  const nonce = randomBytes(16).toString('base64')
  const csp = [
    "default-src 'none'", `script-src 'nonce-${nonce}'`, "style-src 'self' 'unsafe-inline'", "img-src 'self' data:",
    "font-src 'self'", "connect-src 'self'", "base-uri 'none'", "frame-ancestors 'none'",
  ].join('; ')
  return { html: template.replaceAll('<script>', `<script nonce="${nonce}">`), headers: { 'Content-Security-Policy': csp } }
}

const escape = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

function send(res, status, body, headers = {}) {
  res.writeHead(status, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'same-origin',
    ...headers,
  })
  res.end(body)
}

const json = (res, status, data) =>
  send(res, status, JSON.stringify(data), { 'Content-Type': 'application/json; charset=utf-8' })

async function loginPage(res, { retour = '', error = '', status = 200, ident = '', headers = {} } = {}) {
  const safe = protect(await page('connexion.html'))
  const html = safe.html
    .replaceAll('{{RETOUR}}', escape(retour))
    .replaceAll('{{ERREUR}}', error ? `<p class="at-error" role="alert">${escape(error)}</p>` : '')
    .replaceAll('{{INVALIDE}}', error ? ' aria-invalid="true"' : '')
    .replaceAll('{{IDENT}}', escape(ident))
    .replaceAll('{{FOCUS_IDENT}}', ident ? '' : ' autofocus')
    .replaceAll('{{FOCUS_MDP}}', ident ? ' autofocus' : '')
    .replaceAll('{{DOMAINE}}', escape(DOMAIN))
    .replace('{{ICONES}}', await page('atelier-icons.svg'))
    .replaceAll('{{UTILISATEUR}}', escape(USER))
  send(res, status, html, { ...safe.headers, ...headers })
}

/** Corps d'un formulaire. Au-delà de `limit` octets : erreur `status: 413`, le reste n'est pas gardé en mémoire. */
function readBody(req, limit = 4096) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    req.on('data', (chunk) => {
      size += chunk.length
      if (size > limit) return reject(Object.assign(new Error('corps trop long'), { status: 413 }))
      chunks.push(chunk)
    })
    // Les morceaux sont assemblés avant d'être décodés : un caractère accentué peut être à cheval sur deux morceaux.
    req.on('end', () => resolve(new URLSearchParams(Buffer.concat(chunks).toString('utf8'))))
    req.on('error', reject)
  })
}

// Adresse du visiteur : la dernière de X-Forwarded-For, celle que Caddy a lui-même constatée. Les précédentes, s'il y
// en a, viennent du visiteur et peuvent être inventées pour échapper à la limite d'essais.
const clientIp = (req) => String(req.headers['x-forwarded-for'] || '').split(',').pop().trim() || req.socket.remoteAddress

// ── Routeur ─────────────────────────────────────────────────────────────────
const server = createServer(async (req, res) => {
  const url = new URL(req.url, `${SCHEME}://${DOMAIN}`)
  const path = url.pathname

  try {
    if (path === '/sante') return json(res, 200, { status: 'ok' })

    // Logos des apps : publics (aucune donnée), mis en cache une semaine.
    // Après un changement de logo, augmenter ?v= dans index.html pour forcer le rechargement.
    const logo = path.match(/^\/logos\/([a-z]+)\.webp$/)
    if (logo) {
      try {
        const file = await readFile(join(here, 'public', 'logos', `${logo[1]}.webp`))
        res.writeHead(200, { 'Content-Type': 'image/webp', 'Cache-Control': 'public, max-age=604800' })
        return res.end(file)
      } catch {
        return send(res, 404, 'Logo introuvable')
      }
    }

    // Système de design commun : feuille de style, icônes, police. Publics, réutilisables par
    // toutes les apps de la suite (polices servies avec CORS pour les sous-domaines).
    const asset = ASSETS[path] || (path.match(/^\/fonts\/[a-z0-9-]+\.woff2$/) && { file: path.slice(1), type: 'font/woff2' })
    if (asset) {
      try {
        const file = await readFile(join(here, 'public', asset.file))
        res.writeHead(200, {
          'Content-Type': asset.type,
          'Cache-Control': asset.type === 'font/woff2' ? 'public, max-age=31536000, immutable' : 'public, max-age=3600',
          'Access-Control-Allow-Origin': '*',
        })
        return res.end(file)
      } catch {
        return send(res, 404, 'Fichier introuvable')
      }
    }

    // Icônes de la Suite (onglet, Dock, écran d'accueil) : publiques, comme les logos.
    const icone = path === '/apple-touch-icon.png' ? ['apple-touch-icon'] : path.match(/^\/icones\/([a-z0-9-]+)\.png$/)?.slice(1)
    if (icone) {
      try {
        const file = await readFile(join(here, 'public', 'icones', `${icone[0]}.png`))
        res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=604800' })
        return res.end(file)
      } catch {
        return send(res, 404, 'Icône introuvable')
      }
    }

    // Caddy demande « cette requête peut-elle passer ? » avant chaque appel à une app.
    if (path === '/auth/verify') {
      const s = session(req)
      if (s) {
        res.writeHead(200, { 'X-Atelier-User': s.u })
        return res.end()
      }
      const proto = req.headers['x-forwarded-proto'] || SCHEME
      const host = req.headers['x-forwarded-host'] || DOMAIN
      const uri = req.headers['x-forwarded-uri'] || '/'
      const back = safeReturn(`${proto}://${host}${uri}`)
      const accept = String(req.headers.accept || '')
      // Les appels d'API (fetch) reçoivent un 401 net ; la navigation est renvoyée vers la connexion.
      if (!accept.includes('text/html')) return json(res, 401, { error: 'non_connecte' })
      res.writeHead(302, { Location: `${SCHEME}://${DOMAIN}/connexion?retour=${encodeURIComponent(back)}` })
      return res.end()
    }

    // Un autre site ne peut ni déconnecter quelqu'un, ni envoyer le formulaire de connexion à sa place.
    if (req.method === 'POST' && !fromPortal(req)) {
      const error = 'Cette demande ne vient pas du portail. Recharge cette page, puis réessaie.'
      if (path === '/connexion') return loginPage(res, { status: 403, error })
      return send(res, 403, error, { 'Content-Type': 'text/plain; charset=utf-8' })
    }

    if (path === '/connexion' && req.method === 'GET') {
      if (session(req)) {
        res.writeHead(302, { Location: safeReturn(url.searchParams.get('retour') || '') })
        return res.end()
      }
      return loginPage(res, { retour: url.searchParams.get('retour') || '' })
    }

    if (path === '/connexion' && req.method === 'POST') {
      const key = rateKey(clientIp(req))
      const form = await readBody(req)
      const retour = form.get('retour') || ''
      const user = (form.get('utilisateur') || '').trim()
      const ident = user.slice(0, 64) // réaffiché dans le formulaire
      const wait = waitSeconds(key)
      if (wait) {
        const minutes = Math.ceil(wait / 60)
        const error = `Trop d’essais. Réessaie dans ${minutes > 1 ? `${minutes} minutes` : 'une minute'}.`
        return loginPage(res, { retour, status: 429, error, ident, headers: { 'Retry-After': String(wait) } })
      }
      // L'essai est compté avant d'être vérifié : des essais envoyés en même temps ne passent pas tous sous la limite.
      noteAttempt(key)
      const userOk = user.toLowerCase() === USER.toLowerCase()
      const passOk = timingSafeEqual(await digest(form.get('mot_de_passe') || '', salt, 32), passwordDigest)
      if (!userOk || !passOk) {
        return loginPage(res, { retour, status: 401, error: 'Identifiant ou mot de passe incorrect.', ident })
      }
      attempts.delete(key)
      res.writeHead(303, {
        'Set-Cookie': sessionCookie(makeToken(USER), SESSION_DAYS * 86400),
        Location: safeReturn(retour),
      })
      return res.end()
    }

    if (path === '/deconnexion' && req.method === 'POST') {
      res.writeHead(303, { 'Set-Cookie': sessionCookie('', 0), Location: `${SCHEME}://${DOMAIN}/connexion` })
      return res.end()
    }

    // Tout le reste exige une session.
    const s = session(req)
    if (!s) {
      if (path.startsWith('/api/')) return json(res, 401, { error: 'non_connecte' })
      res.writeHead(302, { Location: `/connexion` })
      return res.end()
    }

    if (path === '/api/statut') return json(res, 200, { apps: await statuses(), at: new Date().toISOString() })

    if (path === '/' || path === '/index.html') {
      const safe = protect(await page('index.html'))
      const html = safe.html
        .replace('/*APPS*/[]', JSON.stringify(APPS.map(({ probes, ...a }) => a)))
        .replaceAll('{{UTILISATEUR}}', escape(s.u))
        .replaceAll('{{DOMAINE}}', escape(DOMAIN))
        .replace('{{ICONES}}', await page('atelier-icons.svg'))
      return send(res, 200, html, safe.headers)
    }

    return send(res, 404, 'Page introuvable')
  } catch (err) {
    if (err.status === 413) {
      // La connexion est fermée après la réponse : la suite d'un envoi trop long n'est pas lue.
      send(res, 413, 'Requête trop longue', { Connection: 'close' })
      return req.resume()
    }
    console.error(err)
    return send(res, 500, 'Erreur du portail')
  }
})

server.listen(PORT, HOST, () => console.log(`Portail Atelier sur http://${HOST}:${PORT} pour ${SCHEME}://${DOMAIN}`))

function fail(msg) {
  console.error(`[portail] ${msg}`)
  process.exit(1)
}
