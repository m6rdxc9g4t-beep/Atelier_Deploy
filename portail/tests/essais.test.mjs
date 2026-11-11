// Limite d'essais de connexion : ce qu'un attaquant peut faire varier ne doit pas lui donner d'essais en plus.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { lancer, connexion } from './outils.mjs'

const FAUX = 'mauvais-mot-de-passe'
const BON = 'premier-mot-de-passe'

test('en IPv6, la limite compte par préfixe /64 et non par adresse', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (let i = 1; i <= 8; i++) assert.equal((await connexion(p.base, FAUX, `2001:db8:1:2::${i.toString(16)}`)).status, 401)
  assert.equal((await connexion(p.base, BON, '2001:db8:1:2:aaaa:bbbb:cccc:9')).status, 429, 'une autre adresse du même /64 attend aussi')
  assert.equal((await connexion(p.base, BON, '2001:DB8:1:2::')).status, 429, 'quelle que soit son écriture')
  assert.equal((await connexion(p.base, BON, '2001:db8:1:3::1')).status, 303, 'le /64 voisin se connecte')
  assert.equal((await connexion(p.base, BON, '::ffff:203.0.113.77')).status, 303, 'une adresse IPv4 notée en IPv6 aussi')
})

test('une adresse inventée en tête de X-Forwarded-For ne donne pas d’essais en plus', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  // Caddy ajoute l'adresse qu'il a constatée en dernier : c'est elle qui compte.
  for (let i = 1; i <= 8; i++) assert.equal((await connexion(p.base, FAUX, `10.9.8.${i}, 203.0.113.50`)).status, 401)
  assert.equal((await connexion(p.base, BON, '10.9.8.99, 203.0.113.50')).status, 429)
})

test('des essais envoyés en même temps ne passent pas tous sous la limite', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  const codes = await Promise.all(Array.from({ length: 24 }, () => connexion(p.base, FAUX, '203.0.113.60').then((r) => r.status)))
  assert.equal(codes.filter((c) => c === 401).length, 8, 'huit essais vérifiés, pas un de plus')
  assert.equal(codes.filter((c) => c === 429).length, 16)
})

test('le refus dit combien de temps attendre', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (let i = 0; i < 8; i++) await connexion(p.base, FAUX, '203.0.113.61')
  const { status, res } = await connexion(p.base, BON, '203.0.113.61')
  assert.equal(status, 429)
  const attente = Number(res.headers.get('retry-after'))
  assert.ok(attente > 14 * 60 && attente <= 15 * 60, `Retry-After proche de 15 min (${attente} s)`)
  assert.match(await res.text(), /Réessaie dans 15 minutes/)
})

test('une connexion réussie remet le compteur à zéro', async (t) => {
  const p = await lancer()
  t.after(p.arreter)
  for (let i = 0; i < 7; i++) assert.equal((await connexion(p.base, FAUX, '203.0.113.62')).status, 401)
  assert.equal((await connexion(p.base, BON, '203.0.113.62')).status, 303)
  for (let i = 0; i < 7; i++) assert.equal((await connexion(p.base, FAUX, '203.0.113.62')).status, 401)
  assert.equal((await connexion(p.base, BON, '203.0.113.62')).status, 303)
})
