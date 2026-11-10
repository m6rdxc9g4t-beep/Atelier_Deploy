// Sessions du portail : node --test portail/tests/*.test.mjs   (aucun paquet externe, le serveur est lancé sur un port libre)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { createServer } from 'node:net'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const portail = join(dirname(fileURLToPath(import.meta.url)), '..')
const SECRET = '0123456789abcdef0123456789abcdef0123456789abcdef'

const portLibre = () =>
  new Promise((resolve, reject) => {
    const s = createServer()
    s.once('error', reject)
    s.listen(0, '127.0.0.1', () => {
      const { port } = s.address()
      s.close(() => resolve(port))
    })
  })

/** Lance le portail avec ces réglages ; rend son adresse et de quoi l'arrêter. */
async function lancer(env = {}) {
  const port = await portLibre()
  const proc = spawn(process.execPath, ['server.mjs'], {
    cwd: portail,
    env: {
      PATH: process.env.PATH,
      ATELIER_DOMAIN: 'atelier.exemple.test',
      SITE_SCHEME: 'http',
      PORTAL_PORT: String(port),
      PORTAL_USER: 'francois',
      PORTAL_PASSWORD: 'premier-mot-de-passe',
      SESSION_SECRET: SECRET,
      ...env,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  await new Promise((resolve, reject) => {
    proc.stdout.on('data', (d) => String(d).includes('Portail Atelier') && resolve())
    proc.once('exit', (code) => reject(new Error(`le portail s'est arrêté (code ${code})`)))
    setTimeout(() => reject(new Error('le portail ne démarre pas')), 10_000).unref()
  })
  const arreter = () =>
    new Promise((resolve) => {
      proc.once('exit', resolve)
      proc.kill('SIGKILL')
    })
  return { base: `http://127.0.0.1:${port}`, arreter }
}

/** Se connecte ; rend le cookie de session (« atelier_session=… ») ou null. */
async function connexion(base, motDePasse, ip = '203.0.113.7') {
  const res = await fetch(`${base}/connexion`, {
    method: 'POST',
    redirect: 'manual',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Forwarded-For': ip },
    body: new URLSearchParams({ utilisateur: 'francois', mot_de_passe: motDePasse }),
  })
  const cookie = res.headers.get('set-cookie')
  return { status: res.status, cookie: cookie ? cookie.split(';')[0] : null }
}

const verifier = (base, cookie, accept = 'application/json') =>
  fetch(`${base}/auth/verify`, { redirect: 'manual', headers: { Cookie: cookie, Accept: accept } })

test('une session ouverte laisse passer forward_auth', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const { status, cookie } = await connexion(p.base, 'premier-mot-de-passe')
  assert.equal(status, 303)
  assert.ok(cookie, 'un cookie de session est posé')
  const res = await verifier(p.base, cookie)
  assert.equal(res.status, 200)
  assert.equal(res.headers.get('x-atelier-user'), 'francois')
})

test('une session survit au redémarrage du portail quand rien ne change', async (t) => {
  const a = await lancer()
  const { cookie } = await connexion(a.base, 'premier-mot-de-passe')
  await a.arreter()
  const b = await lancer()
  t.after(b.arreter)
  assert.equal((await verifier(b.base, cookie)).status, 200)
})

test('changer le mot de passe déconnecte les sessions ouvertes avec l’ancien', async (t) => {
  const a = await lancer()
  const { cookie } = await connexion(a.base, 'premier-mot-de-passe')
  await a.arreter()
  const b = await lancer({ PORTAL_PASSWORD: 'second-mot-de-passe' })
  t.after(b.arreter)
  assert.equal((await connexion(b.base, 'premier-mot-de-passe')).status, 401, 'l’ancien mot de passe est refusé')
  assert.equal((await verifier(b.base, cookie)).status, 401, 'l’ancien cookie est refusé pour un appel d’API')
  const navigation = await verifier(b.base, cookie, 'text/html')
  assert.equal(navigation.status, 302, 'la navigation est renvoyée vers la connexion')
  assert.match(navigation.headers.get('location'), /\/connexion\?retour=/)
  const neuf = await connexion(b.base, 'second-mot-de-passe')
  assert.equal((await verifier(b.base, neuf.cookie)).status, 200, 'le nouveau mot de passe ouvre une session')
})

test('un cookie falsifié est refusé', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const { cookie } = await connexion(p.base, 'premier-mot-de-passe')
  const [nom, jeton] = cookie.split('=')
  const [charge] = jeton.split('.')
  assert.equal((await verifier(p.base, `${nom}=${charge}.signature-inventee`)).status, 401)
  assert.equal((await verifier(p.base, `${nom}=`)).status, 401)
})

test('huit échecs bloquent l’adresse un quart d’heure, sans gêner les autres', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (let i = 0; i < 8; i++) assert.equal((await connexion(p.base, 'mauvais-mot-de-passe', '198.51.100.9')).status, 401)
  assert.equal((await connexion(p.base, 'premier-mot-de-passe', '198.51.100.9')).status, 429, 'même le bon mot de passe attend')
  assert.equal((await connexion(p.base, 'premier-mot-de-passe', '198.51.100.10')).status, 303, 'une autre adresse se connecte')
})
