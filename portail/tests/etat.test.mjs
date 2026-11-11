// État des apps et fichiers communs : ce que le portail évite de refaire.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { lancer, connexion } from './outils.mjs'

test('l’état des apps est sondé une fois pour tous les onglets ouverts', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const { cookie } = await connexion(p.base, 'premier-mot-de-passe')
  const etat = () => fetch(`${p.base}/api/statut`, { headers: { Cookie: cookie } }).then((r) => r.json())
  const [a, b, c] = await Promise.all([etat(), etat(), etat()])
  await new Promise((r) => setTimeout(r, 30))
  const d = await etat()
  assert.ok(a.apps.length > 10 && a.apps.every((x) => ['up', 'down', 'partial'].includes(x.state)))
  assert.deepEqual([b.at, c.at, d.at], [a.at, a.at, a.at], 'une seule vérification a servi les quatre demandes')
  const neuf = await fetch(`${p.base}/api/statut?frais`, { headers: { Cookie: cookie } }).then((r) => r.json())
  assert.notEqual(neuf.at, a.at, '« Vérifier maintenant » relance une vraie vérification')
  assert.equal((await fetch(`${p.base}/api/statut`)).status, 401, 'toujours réservé aux personnes connectées')
})

test('la feuille de style et les icônes se revalident sans être retéléchargées', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (const chemin of ['/atelier.css', '/atelier-icons.svg']) {
    const premiere = await fetch(`${p.base}${chemin}`)
    const etag = premiere.headers.get('etag')
    assert.equal(premiere.status, 200)
    assert.ok(etag, `${chemin} porte une empreinte`)
    const seconde = await fetch(`${p.base}${chemin}`, { headers: { 'If-None-Match': etag } })
    assert.equal(seconde.status, 304)
    assert.equal((await seconde.arrayBuffer()).byteLength, 0)
    assert.equal((await fetch(`${p.base}${chemin}`, { headers: { 'If-None-Match': '"autre"' } })).status, 200)
  }
})
