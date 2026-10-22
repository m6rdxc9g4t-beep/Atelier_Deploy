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
import { createHmac, timingSafeEqual, randomBytes, scryptSync } from 'node:crypto'
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

/** Les apps du portail. `sub` = sous-domaine ; `probe` = adresse locale sondée par le serveur. */
const APPS = [
  {
    id: 'nexus', name: 'Nexus', role: 'Workflows et agents IA de la suite', color: '#E8590C', sub: 'nexus',
    probes: ['http://127.0.0.1:8100/health', 'http://127.0.0.1:3100/'],
  },
  {
    id: 'viz', name: 'Viz', role: 'BI : jeux de données, rapports, alertes', color: '#F2C811', sub: 'viz',
    probes: ['http://127.0.0.1:8000/api/health'],
  },
  {
    id: 'tab', name: 'Tab', role: 'Tableur et base typée', color: '#21A366', sub: 'tab',
    probes: [], // app statique servie par Caddy : toujours disponible si le portail l'est
  },
  {
    id: 'projets', name: 'Projets', role: 'Projets agiles, jalons, temps passé', color: '#94D82D', sub: 'projets',
    probes: ['http://127.0.0.1:3000/api/health'],
  },
].map((a) => ({ ...a, url: `${SCHEME}://${a.sub}.${DOMAIN}/` }))

// ── Session signée (HMAC-SHA256), sans stockage côté serveur ────────────────
const b64 = (buf) => Buffer.from(buf).toString('base64url')
const sign = (data) => createHmac('sha256', SECRET).update(data).digest('base64url')

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

function cookies(req) {
  const out = {}
  for (const part of (req.headers.cookie || '').split(';')) {
    const i = part.indexOf('=')
    if (i > 0) out[part.slice(0, i).trim()] = decodeURIComponent(part.slice(i + 1).trim())
  }
  return out
}

const session = (req) => readToken(cookies(req)[COOKIE])

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

// ── Limite d'essais de connexion : 8 échecs par IP sur 15 min ───────────────
const attempts = new Map()
function tooManyAttempts(ip) {
  const now = Date.now()
  const list = (attempts.get(ip) || []).filter((t) => now - t < 15 * 60e3)
  attempts.set(ip, list)
  return list.length >= 8
}
const noteFailure = (ip) => attempts.set(ip, [...(attempts.get(ip) || []), Date.now()])

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
  return Promise.all(
    APPS.map(async (a) => {
      if (!a.probes.length) return { id: a.id, state: 'up', ms: null }
      const results = await Promise.all(a.probes.map(probe))
      const up = results.filter((r) => r.ok).length
      const state = up === results.length ? 'up' : up === 0 ? 'down' : 'partial'
      const ms = results.every((r) => r.ms != null) ? Math.max(...results.map((r) => r.ms)) : null
      return { id: a.id, state, ms }
    }),
  )
}

// ── Pages ───────────────────────────────────────────────────────────────────
const pages = {}
async function page(name) {
  if (!pages[name] || env.PORTAL_DEV) pages[name] = await readFile(join(here, 'public', name), 'utf8')
  return pages[name]
}

const escape = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

function send(res, status, body, headers = {}) {
  res.writeHead(status, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'same-origin',
    ...headers,
  })
  res.end(body)
}

const json = (res, status, data) =>
  send(res, status, JSON.stringify(data), { 'Content-Type': 'application/json; charset=utf-8' })

async function loginPage(res, { retour = '', error = '', status = 200 } = {}) {
  const html = (await page('connexion.html'))
    .replaceAll('{{RETOUR}}', escape(retour))
    .replaceAll('{{ERREUR}}', error ? `<p class="error" role="alert">${escape(error)}</p>` : '')
    .replaceAll('{{UTILISATEUR}}', escape(USER))
  send(res, status, html)
}

function readBody(req, limit = 4096) {
  return new Promise((resolve, reject) => {
    let data = ''
    req.on('data', (chunk) => {
      data += chunk
      if (data.length > limit) reject(new Error('trop long'))
    })
    req.on('end', () => resolve(new URLSearchParams(data)))
    req.on('error', reject)
  })
}

const clientIp = (req) => (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || req.socket.remoteAddress

// ── Routeur ─────────────────────────────────────────────────────────────────
const server = createServer(async (req, res) => {
  const url = new URL(req.url, `${SCHEME}://${DOMAIN}`)
  const path = url.pathname

  try {
    if (path === '/sante') return json(res, 200, { status: 'ok' })

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

    if (path === '/connexion' && req.method === 'GET') {
      if (session(req)) {
        res.writeHead(302, { Location: safeReturn(url.searchParams.get('retour') || '') })
        return res.end()
      }
      return loginPage(res, { retour: url.searchParams.get('retour') || '' })
    }

    if (path === '/connexion' && req.method === 'POST') {
      const ip = clientIp(req)
      const form = await readBody(req)
      const retour = form.get('retour') || ''
      if (tooManyAttempts(ip)) {
        return loginPage(res, { retour, status: 429, error: 'Trop d’essais. Réessaie dans un quart d’heure.' })
      }
      const userOk = (form.get('utilisateur') || '').trim().toLowerCase() === USER.toLowerCase()
      const passOk = timingSafeEqual(scryptSync(form.get('mot_de_passe') || '', salt, 32), passwordDigest)
      if (!userOk || !passOk) {
        noteFailure(ip)
        return loginPage(res, { retour, status: 401, error: 'Identifiant ou mot de passe incorrect.' })
      }
      attempts.delete(ip)
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
      const html = (await page('index.html'))
        .replace('/*APPS*/[]', JSON.stringify(APPS.map(({ probes, ...a }) => a)))
        .replaceAll('{{UTILISATEUR}}', escape(s.u))
        .replaceAll('{{DOMAINE}}', escape(DOMAIN))
      return send(res, 200, html)
    }

    return send(res, 404, 'Page introuvable')
  } catch (err) {
    console.error(err)
    return send(res, 500, 'Erreur du portail')
  }
})

server.listen(PORT, HOST, () => console.log(`Portail Atelier sur http://${HOST}:${PORT} pour ${SCHEME}://${DOMAIN}`))

function fail(msg) {
  console.error(`[portail] ${msg}`)
  process.exit(1)
}
