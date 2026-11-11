// La page du portail dans un vrai navigateur. Sauté si Playwright n'est pas installé sur la machine
// (aucun paquet n'est ajouté au dépôt) :  node --test portail/tests/page.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { lancer, connexion } from './outils.mjs'

let chromium = null
try {
  ;({ chromium } = createRequire(import.meta.url)('playwright'))
} catch {}
const options = { skip: chromium ? false : 'Playwright introuvable' }

/** Ouvre le portail, connecté ; rend la page et la liste des erreurs de console. */
async function ouvrir(t, { largeur = 1280, hauteur = 800, tactile = false } = {}) {
  const p = await lancer()
  const navigateur = await chromium.launch()
  t.after(async () => {
    await navigateur.close()
    await p.arreter()
  })
  const { cookie } = await connexion(p.base, 'premier-mot-de-passe')
  const contexte = await navigateur.newContext({ viewport: { width: largeur, height: hauteur }, hasTouch: tactile, isMobile: tactile })
  const [name, value] = cookie.split('=')
  await contexte.addCookies([{ name, value, url: p.base }])
  const page = await contexte.newPage()
  const erreurs = []
  page.on('console', (m) => m.type() === 'error' && erreurs.push(m.text()))
  page.on('pageerror', (e) => erreurs.push(String(e)))
  const etat = page.waitForResponse((r) => r.url().includes('/api/statut'))
  await page.goto(`${p.base}/`)
  await etat
  return { page, erreurs, base: p.base }
}

/** Relance la vérification de l'état sans déplacer le focus (comme le fait la page toutes les 20 s). */
async function rafraichir(page) {
  const etat = page.waitForResponse((r) => r.url().includes('/api/statut'))
  await page.evaluate(() => document.getElementById('refresh').dispatchEvent(new Event('click')))
  await etat
  await page.waitForFunction(() => !document.getElementById('refresh').classList.contains('is-busy'))
}

test('la page s’affiche sans erreur, apps et état compris', options, async (t) => {
  const { page, erreurs } = await ouvrir(t)
  assert.ok((await page.locator('#content [data-i]').count()) >= 30, 'les apps sont listées')
  assert.match(await page.textContent('#health'), /\d+ sur \d+ en ligne/)
  assert.deepEqual(erreurs, [])
})

test('la vérification périodique ne fait pas perdre le focus au clavier', options, async (t) => {
  const { page } = await ouvrir(t)
  const actif = () => page.evaluate(() => {
    const e = document.activeElement
    return `${e.className}|${e.closest('[data-i]')?.querySelector('.name')?.textContent ?? ''}`
  })
  await page.focus('#content [data-i="3"] .row-link')
  const lien = await actif()
  await rafraichir(page)
  assert.equal(await actif(), lien, 'le lien de la ligne garde le focus')
  await page.focus('#content [data-copy]')
  const copie = await actif()
  await rafraichir(page)
  assert.equal(await actif(), copie, 'le bouton « Copier le lien » aussi')
})

test('l’état du serveur n’est réannoncé aux lecteurs d’écran que s’il change', options, async (t) => {
  const { page } = await ouvrir(t)
  // Ce qui est dans la zone « aria-live » ne doit pas changer d'une vérification à l'autre (l'heure, elle, change).
  await page.evaluate(() => {
    window.__annonces = 0
    new MutationObserver(() => window.__annonces++).observe(document.querySelector('#health [aria-live]'), { childList: true, subtree: true, characterData: true })
  })
  await page.waitForTimeout(1100)
  const heure = await page.textContent('#health-time')
  await rafraichir(page)
  assert.notEqual(await page.textContent('#health-time'), heure, 'l’heure de la vérification avance')
  assert.equal(await page.evaluate(() => window.__annonces), 0, 'rien n’est réannoncé')
})

test('un filtre inconnu resté en mémoire retombe sur « Toutes les apps »', options, async (t) => {
  const { page } = await ouvrir(t)
  await page.evaluate(() => localStorage.setItem('atelier:filter', 'ancien-groupe'))
  await page.reload()
  assert.equal(await page.textContent('#title'), 'Toutes les apps')
  assert.ok((await page.locator('#content [data-i]').count()) >= 30)
})

test('au téléphone, toute cible fait au moins 40 px et rien ne déborde', options, async (t) => {
  const { page, base } = await ouvrir(t, { largeur: 390, hauteur: 844, tactile: true })
  const mesurer = () => page.evaluate(() => {
    const petites = []
    for (const e of document.querySelectorAll('button, a, input, .search')) {
      if (!e.offsetParent || e.closest('.search') && e.tagName === 'INPUT') continue
      const zone = e.classList.contains('row-link') ? e.closest('[data-i]') : e // lien étiré sur toute la ligne
      const r = zone.getBoundingClientRect()
      const apres = getComputedStyle(e, '::after') // zone de toucher agrandie par un pseudo-élément
      const marge = zone === e && apres.position === 'absolute' ? -2 * (parseFloat(apres.top) || 0) : 0
      // 39,5 : une largeur calculée peut tomber à 39,99 px
      if (r.height + marge < 39.5 || r.width < 39.5) petites.push(`${e.title || e.textContent.trim() || e.id} : ${Math.round(r.width)} × ${Math.round(r.height + marge)}`)
    }
    return { petites, debordement: document.documentElement.scrollWidth - innerWidth }
  })
  assert.deepEqual(await mesurer(), { petites: [], debordement: 0 }, 'liste')
  await page.tap('[data-view="grid"]')
  assert.deepEqual(await mesurer(), { petites: [], debordement: 0 }, 'icônes')
  assert.equal(await page.evaluate(() => getComputedStyle(document.getElementById('q')).fontSize), '16px', 'recherche à 16 px : pas de zoom sur iPhone')
  await page.context().clearCookies()
  await page.goto(`${base}/connexion`)
  const champs = await page.evaluate(() => [...document.querySelectorAll('.at-input, button')].map((e) => [e.tagName, e.getBoundingClientRect().height, parseFloat(getComputedStyle(e).fontSize)]))
  for (const [balise, hauteur, taille] of champs) {
    assert.ok(hauteur >= 44, `connexion : ${balise} de ${hauteur} px`)
    if (balise === 'INPUT') assert.ok(taille >= 16, `connexion : champ à ${taille} px (zoom sur iPhone sous 16 px)`)
  }
  assert.equal(await page.getAttribute('[name=utilisateur]', 'autocapitalize'), 'none')
})
