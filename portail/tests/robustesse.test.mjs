// Ce que le portail reçoit d'Internet ou des apps ne doit jamais le faire répondre « 500 » :
// forward_auth de Caddy lit ce code pour chaque requête vers une app.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { lancer, connexion, verifier } from './outils.mjs'

test('un cookie mal encodé posé par une app ne coupe pas l’accès à cette app', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const { cookie } = await connexion(p.base, 'premier-mot-de-passe')
  // « 100% » n'est pas un encodage valide : decodeURIComponent lève une erreur dessus.
  for (const autres of ['prefs=100%', 'a=%E0%A4%A; b=%', 'vide=; =sans-nom; %=%']) {
    assert.equal((await verifier(p.base, `${autres}; ${cookie}`)).status, 200, `session reconnue à côté de « ${autres} »`)
    assert.equal((await verifier(p.base, `${cookie}; ${autres}`)).status, 200, `session reconnue avant « ${autres} »`)
    assert.equal((await verifier(p.base, autres)).status, 401, `sans session : refus net, pas d’erreur (« ${autres} »)`)
  }
})

test('un vieux cookie de session resté dans le navigateur ne masque pas le bon', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const { cookie } = await connexion(p.base, 'premier-mot-de-passe')
  assert.equal((await verifier(p.base, `atelier_session=perime.invalide; ${cookie}`)).status, 200)
  assert.equal((await verifier(p.base, `${cookie}; atelier_session=perime.invalide`)).status, 200)
  assert.equal((await verifier(p.base, 'atelier_session=perime.invalide; atelier_session=')).status, 401)
})

test('un formulaire de connexion trop long est refusé (413), sans erreur du portail', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const res = await fetch(`${p.base}/connexion`, {
    method: 'POST',
    redirect: 'manual',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ utilisateur: 'francois', mot_de_passe: 'x'.repeat(20_000) }),
  })
  assert.equal(res.status, 413)
  // Le portail répond toujours ensuite.
  assert.equal((await connexion(p.base, 'premier-mot-de-passe')).status, 303)
})

test('un mot de passe accentué reçu en plusieurs morceaux est lu en entier', async (t) => {
  const motDePasse = 'été-à-Noël-çà-et-là-€'
  const p = await lancer({ PORTAL_PASSWORD: motDePasse })
  t.after(p.arreter)
  const { request } = await import('node:http')
  const corps = Buffer.from(new URLSearchParams({ utilisateur: 'francois', mot_de_passe: 'x' }).toString().replace(/x$/, motDePasse))
  const status = await new Promise((resolve, reject) => {
    const req = request(`${p.base}/connexion`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': corps.length } }, (res) => {
      res.resume()
      resolve(res.statusCode)
    })
    req.on('error', reject)
    // Coupe au milieu d'un caractère de plusieurs octets (« é » = 2 octets, « € » = 3).
    const coupe = corps.indexOf(Buffer.from('é')) + 1
    req.write(corps.subarray(0, coupe))
    setTimeout(() => req.end(corps.subarray(coupe)), 60)
  })
  assert.equal(status, 303)
})
