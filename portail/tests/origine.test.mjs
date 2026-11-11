// Les formulaires du portail n'acceptent que ce qui vient du portail : un autre site ne peut ni déconnecter
// quelqu'un, ni le connecter à son insu.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { lancer, connexion } from './outils.mjs'

const poster = (base, chemin, origine, corps = '') =>
  fetch(`${base}${chemin}`, {
    method: 'POST',
    redirect: 'manual',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...(origine === undefined ? {} : { Origin: origine }) },
    body: corps,
  })

test('un autre site ne peut pas déconnecter quelqu’un', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (const origine of ['https://mechant.example', 'http://atelier.exemple.test.mechant.example', 'http://portfolio.atelier.exemple.test', 'null']) {
    const res = await poster(p.base, '/deconnexion', origine)
    assert.equal(res.status, 403, `refusé depuis ${origine}`)
    assert.equal(res.headers.get('set-cookie'), null, 'le cookie de session n’est pas effacé')
  }
})

test('le bouton « Se déconnecter » du portail fonctionne', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (const origine of ['http://atelier.exemple.test', 'http://ATELIER.exemple.test', undefined]) {
    const res = await poster(p.base, '/deconnexion', origine)
    assert.equal(res.status, 303, `accepté depuis ${origine ?? 'un client sans en-tête Origin'}`)
    assert.match(res.headers.get('set-cookie'), /^atelier_session=;.*Max-Age=0/)
  }
})

test('un autre site ne peut pas envoyer le formulaire de connexion', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const corps = new URLSearchParams({ utilisateur: 'francois', mot_de_passe: 'premier-mot-de-passe' }).toString()
  const refus = await poster(p.base, '/connexion', 'https://mechant.example', corps)
  assert.equal(refus.status, 403)
  assert.equal(refus.headers.get('set-cookie'), null)
  assert.match(await refus.text(), /Recharge cette page/)
  assert.equal((await poster(p.base, '/connexion', 'http://atelier.exemple.test', corps)).status, 303)
  // Un refus ne compte pas comme un essai raté : un autre site ne peut pas fermer la connexion au propriétaire.
  for (let i = 0; i < 10; i++) await poster(p.base, '/connexion', 'https://mechant.example', corps)
  assert.equal((await connexion(p.base, 'premier-mot-de-passe', '127.0.0.1')).status, 303)
})

test('les pages n’exécutent que leurs propres scripts (CSP à jeton unique)', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const { cookie } = await connexion(p.base, 'premier-mot-de-passe')
  const jetons = []
  for (const [chemin, entetes] of [['/connexion', {}], ['/', { Cookie: cookie }]]) {
    const res = await fetch(`${p.base}${chemin}`, { headers: entetes, redirect: 'manual' })
    assert.equal(res.status, 200)
    const csp = res.headers.get('content-security-policy')
    const jeton = csp.match(/script-src 'nonce-([^']+)'/)?.[1]
    assert.ok(jeton, `${chemin} : script-src porte un jeton`)
    assert.match(csp, /default-src 'none'/)
    assert.doesNotMatch(csp, /script-src[^;]*unsafe-inline/)
    const scripts = (await res.text()).match(/<script[^>]*>/g)
    assert.ok(scripts.length > 0)
    for (const s of scripts) assert.equal(s, `<script nonce="${jeton}">`, `${chemin} : chaque script porte le jeton`)
    assert.equal(res.headers.get('x-content-type-options'), 'nosniff')
    jetons.push(jeton)
  }
  const autre = await fetch(`${p.base}/connexion`)
  assert.ok(!jetons.includes(autre.headers.get('content-security-policy').match(/nonce-([^']+)/)[1]), 'un jeton par réponse')
})
