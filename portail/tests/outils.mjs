// Outils communs aux tests du portail (aucun paquet externe ; le serveur est lancé sur un port libre).
import { spawn } from 'node:child_process'
import { createServer } from 'node:net'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const portail = join(dirname(fileURLToPath(import.meta.url)), '..')
export const SECRET = '0123456789abcdef0123456789abcdef0123456789abcdef'

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
export async function lancer(env = {}) {
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
export async function connexion(base, motDePasse, ip = '203.0.113.7') {
  const res = await fetch(`${base}/connexion`, {
    method: 'POST',
    redirect: 'manual',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Forwarded-For': ip },
    body: new URLSearchParams({ utilisateur: 'francois', mot_de_passe: motDePasse }),
  })
  const cookie = res.headers.get('set-cookie')
  return { status: res.status, cookie: cookie ? cookie.split(';')[0] : null, res }
}

export const verifier = (base, cookie, accept = 'application/json') =>
  fetch(`${base}/auth/verify`, { redirect: 'manual', headers: { Cookie: cookie, Accept: accept } })
