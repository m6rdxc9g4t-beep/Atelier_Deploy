"""Génère les exemples de la suite (format `atelier-exemples/1`) à partir des histoires de `histoires/`.

Chaque app reçoit un dossier `exemples-suite/` :

    exemples-suite/
    ├── index.json            les histoires (titre, résumé, parcours d'une app à l'autre)
    ├── <histoire>.json       la part de cette app pour cette histoire
    └── <histoire>/…          fichiers (Convert : relevés PDF et CSV)

Les données d'une histoire sont les mêmes dans toutes les apps : ce que l'une produit est ce que la suivante
reçoit (relevé PDF → table → jeu → budget → tâche → page).

    python3 -m venv /tmp/fab && /tmp/fab/bin/pip install reportlab
    /tmp/fab/bin/python exemples/generer.py                     # → exemples/dist/<app>/exemples-suite/
    /tmp/fab/bin/python exemples/generer.py --vers ~/Ateliers   # copie aussi dans les dépôts voisins
"""

from __future__ import annotations

import argparse
import csv
import importlib
import json
import shutil
import sys
import unicodedata
from pathlib import Path
from typing import Any

ICI = Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))

from histoires.commun import LIBELLES_MOIS, MOIS, STATUTS, euros, operations, releves, total  # noqa: E402

FORMAT = "atelier-exemples/1"
HISTOIRES = ["studio_garance", "renovation_urbaine", "app_ecommerce", "freelance_data", "finance_patrimoine",
             "marketing_campagne", "assurance_courtage", "boutique_librairie", "immobilier_locatif"]
APPS = ["convert", "tab", "viz", "tresorerie", "nexus", "projets", "wiki"]
NOMS = {"convert": "Atelier Convert", "tab": "Atelier Tab", "viz": "Atelier Viz", "tresorerie": "Atelier Trésorerie",
        "nexus": "Atelier Nexus", "projets": "Atelier Projets", "wiki": "Atelier Wiki"}
# Dossier de chaque app dans un espace de travail (`--vers`), comme sur le Mac et sur le VPS.
DEPOTS = {"convert": ["Atelier_Convert", "atelier_convert"], "tab": ["Atelier_Tab", "atelier-tab"],
          "viz": ["Atelier_Viz", "atelier_viz"], "tresorerie": ["Atelier_Tr-sorerie", "atelier_tr-sorerie"],
          "nexus": ["Atelier_Nexus", "atelier_nexus"], "projets": ["Atelier_Projets", "atelier_projets"],
          "wiki": ["Atelier_Wiki", "atelier_wiki"]}


def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    out = "".join(c if c.isalnum() else "_" for c in s)
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_")


def iso_fr(d: str) -> str:
    return f"{d[8:10]}/{d[5:7]}/{d[0:4]}"


def fr(v: float) -> str:
    whole, dec = f"{abs(v):,.2f}".split(".")
    return whole.replace(",", " ") + "," + dec


# ─── Préparation d'une histoire ────────────────────────────────────────────────────────────────


def charger(nom: str) -> dict[str, Any]:
    h = dict(importlib.import_module(f"histoires.{nom}").HISTOIRE)
    ops = operations(h.get("recurrentes", []), h.get("ponctuelles", []), h.get("graine", 0))
    h["operations"] = ops
    h["releves"] = releves(h["solde_initial"], ops)
    for r in h["releves"]:
        if r["solde_final"] < 0:
            raise SystemExit(f"{h['id']} : solde négatif fin {r['mois']} ({r['solde_final']})")
    a = h["viz"]["alerte"]
    h["alerte_valeur"] = total(ops, MOIS[-1], "debit", a["categorie"])
    if h["alerte_valeur"] <= a["seuil"]:
        raise SystemExit(f"{h['id']} : l'alerte « {a['nom']} » ne se déclenche pas ({h['alerte_valeur']} ≤ {a['seuil']})")
    h["tab_ids"] = {"espace": f"ws_ex_{h['id']}", "projet": f"prj_ex_{h['id']}"}
    h["cle_operations"] = f"exemple:{h['id']}:operations"
    return h


def meta(h: dict[str, Any]) -> dict[str, Any]:
    return {k: h[k] for k in ("id", "titre", "sous_titre", "secteur", "resume")}


def parcours(h: dict[str, Any]) -> list[dict[str, str]]:
    a, dernier = h["viz"]["alerte"], LIBELLES_MOIS[MOIS[-1]]
    extra = h["convert"]["autres"]
    tables = ", ".join(f"« {t['nom']} »" for t in h["tab"]["tables"])
    alerte_story = next((s["titre"] for p in h["projets"]["phases"] for e in p["epics"] for s in e["stories"] if s.get("alertes")),
                        "Suivi des budgets")
    return [
        {"app": "convert", "titre": "Convertir les relevés",
         "texte": f"Convertissez le relevé de {dernier} (PDF) : les soldes sont contrôlés. « Envoyer dans Atelier Tab » "
                  f"le range dans le projet « {h['tab']['projet']} » ; l'export CSV français part dans Trésorerie."
                  + (f" Essayez aussi « {extra[0]['titre']} »." if extra else "")},
        {"app": "tab", "titre": "Ranger et enrichir",
         "texte": f"Le projet « {h['tab']['projet']} » réunit les opérations catégorisées et {tables}."},
        {"app": "viz", "titre": "Analyser et surveiller",
         "texte": f"Le jeu des opérations alimente les graphiques ; l'alerte « {a['nom']} » se déclenche : "
                  f"{euros(h['alerte_valeur'])} pour un seuil de {euros(a['seuil'])}."},
        {"app": "tresorerie", "titre": "Comparer au budget",
         "texte": f"Le compte « {h['tresorerie']['compte']} » et ses budgets de {dernier} : "
                  f"« {a['categorie']} » est en dépassement."},
        {"app": "nexus", "titre": "Enchaîner et réagir",
         "texte": "Les workflows de l'exemple enchaînent les apps en un lancement, chaque écriture attend « Autoriser » ; "
                  "un déclencheur réagit à l'alerte de Viz."},
        {"app": "projets", "titre": "Suivre les actions",
         "texte": f"Le projet « {h['projets']['projet']} » ; l'alerte devient une tâche dans la story « {alerte_story} »."},
        {"app": "wiki", "titre": "Garder la mémoire",
         "texte": f"L'espace « {h['wiki']['espace']} » : parcours de l'exemple, bilans mensuels et procédures, reliés entre eux."},
    ]


# ─── Parts par app ─────────────────────────────────────────────────────────────────────────────


def part_convert(h: dict[str, Any], dossier: Path) -> dict[str, Any]:
    from reportlab.lib.pagesizes import A4  # dépendance de génération uniquement
    from reportlab.pdfgen.canvas import Canvas

    fichiers = []
    (dossier / h["id"]).mkdir(parents=True, exist_ok=True)
    for r in h["releves"]:
        nom = f"{h['id']}/releve-{r['mois']}.pdf"
        releve_pdf(Canvas, A4, dossier / nom, h["banque"], r)
        fichiers.append({"fichier": nom, "titre": f"Relevé {r['libelle']} (PDF)",
                         "description": f"{len(r['operations'])} opérations, solde final {euros(r['solde_final'])}.",
                         "type": "releve", "nom_conversion": f"Relevé {r['libelle']} — {h['titre']}"})
    for x in h["convert"]["autres"]:
        nom = f"{h['id']}/{x['fichier']}"
        with (dossier / nom).open("w", encoding="utf-8", newline="") as f:
            w = csv.writer(f, delimiter=";", lineterminator="\n")
            w.writerow(x["colonnes"])
            w.writerows(x["lignes"])
        fichiers.append({"fichier": nom, "titre": x["titre"], "description": x["description"], "type": "csv",
                         "nom_conversion": f"{x['titre'].split(' (')[0]} — {h['titre']}"})
    # Le CSV français des opérations : importable dans Trésorerie (et dans Tab).
    nom = f"{h['id']}/operations-{MOIS[0]}-{MOIS[-1]}.csv"
    with (dossier / nom).open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";", lineterminator="\n")
        w.writerow(["Date", "Libellé", "Débit", "Crédit", "Catégorie"])
        for o in h["operations"]:
            w.writerow([iso_fr(o["date"]), o["libelle"], fr(o["debit"]) if o["debit"] else "",
                        fr(o["credit"]) if o["credit"] else "", o["categorie"]])
    fichiers.append({"fichier": nom, "titre": "Opérations catégorisées (CSV)",
                     "description": "Les trois mois, catégorisés, au format CSV français : à importer dans Trésorerie.",
                     "type": "csv", "nom_conversion": f"Opérations catégorisées — {h['titre']}"})
    return {"format": FORMAT, "histoire": meta(h), "tab": {"projet_id": h["tab_ids"]["projet"], "projet": h["tab"]["projet"]},
            "fichiers": fichiers}


def releve_pdf(Canvas: Any, A4: Any, path: Path, banque: dict[str, str], r: dict[str, Any]) -> None:
    ops = r["operations"]
    debit, credit = round(sum(o["debit"] for o in ops), 2), round(sum(o["credit"] for o in ops), 2)
    m, an = r["mois"], r["mois"][:4]
    fin = {"08": "31", "09": "30", "10": "31"}[m[5:]]
    veille = {"08": "31/07", "09": "31/08", "10": "30/09"}[m[5:]]
    c = Canvas(str(path), pagesize=A4, invariant=1)  # reproductible : ni date ni identifiant aléatoire
    c.setTitle(f"Relevé {r['libelle']} — {banque['titulaire']} (fictif)")
    width, height = A4
    par_page = 18

    def header(page: int, pages: int) -> float:
        c.setFont("Helvetica-Bold", 14)
        c.drawString(40, height - 50, banque["nom"])
        c.setFont("Helvetica", 9)
        c.drawString(40, height - 64, banque["agence"])
        c.setFont("Helvetica-Bold", 11)
        c.drawString(40, height - 95, "RELEVÉ DE COMPTE")
        c.setFont("Helvetica", 9)
        c.drawString(40, height - 109, f"{banque['titulaire']} — {banque['compte']}")
        c.drawString(40, height - 121, f"Période du 01/{m[5:]}/{an} au {fin}/{m[5:]}/{an}")
        c.drawRightString(width - 40, height - 95, f"Page {page}/{pages}")
        y = height - 150
        c.setFont("Helvetica-Bold", 9)
        for x, t in ((40, "Date"), (85, "Valeur"), (135, "Nature des opérations")):
            c.drawString(x, y, t)
        c.drawRightString(470, y, "Débit")
        c.drawRightString(555, y, "Crédit")
        c.line(40, y - 4, width - 40, y - 4)
        c.setFont("Helvetica", 9)
        return y - 18

    pages = max(2, -(-len(ops) // par_page))
    cut = max(1, -(-len(ops) // pages))
    page = 1
    y = header(page, pages)
    c.drawString(135, y, f"Ancien solde au {veille}/{an}")
    c.drawRightString(555, y, fr(r["solde_initial"]))
    y -= 18
    for i, o in enumerate(ops):
        if i and i % cut == 0:
            c.setFont("Helvetica-Oblique", 8)
            c.drawString(135, y - 4, "À reporter")
            c.showPage()
            page += 1
            y = header(page, pages)
        d = f"{o['date'][8:10]}/{o['date'][5:7]}"
        c.drawString(40, y, d)
        c.drawString(85, y, d)
        lignes = couper(o["libelle"], 38)
        c.drawString(135, y, lignes[0])
        if o["debit"]:
            c.drawRightString(470, y, fr(o["debit"]))
        if o["credit"]:
            c.drawRightString(555, y, fr(o["credit"]))
        for suite in lignes[1:]:  # libellé long : suite sur la ligne d'en dessous, comme les banques
            y -= 11
            c.drawString(135, y, suite)
        y -= 16
    c.line(40, y + 8, width - 40, y + 8)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(135, y - 4, "Total des opérations")
    c.drawRightString(470, y - 4, fr(debit))
    c.drawRightString(555, y - 4, fr(credit))
    c.drawString(135, y - 20, f"Nouveau solde au {fin}/{m[5:]}/{an} créditeur")
    c.drawRightString(555, y - 20, fr(r["solde_final"]))
    c.setFont("Helvetica", 7)
    c.drawString(40, 40, "Document fictif — exemples de la suite Atelier. Aucune donnée réelle.")
    c.save()


def couper(texte: str, largeur: int) -> list[str]:
    """Coupe un libellé aux espaces en lignes d'au plus `largeur` caractères."""
    lignes, cur = [], ""
    for mot in texte.split():
        if cur and len(cur) + 1 + len(mot) > largeur:
            lignes.append(cur)
            cur = mot
        else:
            cur = f"{cur} {mot}".strip()
    if cur:
        lignes.append(cur)
    # Jamais un mot très court seul sur la dernière ligne (« APT » / « 5 ») : il serait pris pour autre chose.
    if len(lignes) > 1 and len(lignes[-1]) <= 4 and " " in lignes[-2]:
        avant, dernier = lignes[-2].rsplit(" ", 1)
        lignes[-2:] = [avant, f"{dernier} {lignes[-1]}"]
    return lignes


def table_operations(h: dict[str, Any]) -> dict[str, Any]:
    """Les opérations des trois mois, catégorisées : ce que l'on obtient après Convert puis la colonne Catégorie de Tab."""
    cats = sorted({o["categorie"] for o in h["operations"]})
    return {
        "nom": "Opérations août-oct. 2026",
        "colonnes": [{"label": "Date", "type": "date"}, {"label": "Libellé", "type": "text", "mapping": "entity_title"},
                     {"label": "Débit", "type": "currency"}, {"label": "Crédit", "type": "currency"},
                     {"label": "Montant", "type": "currency"}, {"label": "Catégorie", "type": "select", "choices": cats},
                     {"label": "Mois", "type": "text"}],
        "lignes": [{"Date": o["date"], "Libellé": o["libelle"], "Débit": o["debit"] or None, "Crédit": o["credit"] or None,
                    "Montant": round(o["credit"] - o["debit"], 2), "Catégorie": o["categorie"], "Mois": o["date"][:7]}
                   for o in h["operations"]],
    }


def part_tab(h: dict[str, Any]) -> dict[str, Any]:
    return {"format": FORMAT, "histoire": meta(h),
            "espace": {"id": h["tab_ids"]["espace"], "nom": h["tab"]["espace"]},
            "projet": {"id": h["tab_ids"]["projet"], "nom": h["tab"]["projet"]},
            "tables": [table_operations(h)] + h["tab"]["tables"]}


VIZ_TYPES = {"text": "string", "select": "string", "currency": "number", "number": "number", "percent": "number",
             "date": "date", "checkbox": "boolean", "formula": "number"}


def atelier_table(nom: str, colonnes: list[dict[str, Any]], lignes: list[dict[str, Any]]) -> dict[str, Any]:
    cols, keys = [], {}
    for c in colonnes:
        if c["type"] == "formula":
            continue  # recalculée par Tab ; pas de valeur à transmettre ici
        k = slug(c["label"]) or "colonne"
        keys[c["label"]] = k
        cols.append({"key": k, "label": c["label"], "type": VIZ_TYPES.get(c["type"], "string")})
    return {"format": "atelier-table/1", "name": slug(nom), "label": nom, "columns": cols,
            "rows": [{keys[l]: v for l, v in ligne.items() if l in keys} for ligne in lignes]}


def csv_table(x: dict[str, Any]) -> dict[str, Any]:
    """Table d'un CSV d'exemple, typée comme le ferait Convert (dates JJ/MM/AAAA, nombres « 1 234,56 », %)."""
    def conv(v: str) -> tuple[Any, str]:
        s = v.strip()
        if len(s) == 10 and s[2] == "/" and s[5] == "/":
            return f"{s[6:]}-{s[3:5]}-{s[:2]}", "date"
        t = s.replace(" ", "").replace(" ", "")
        pct = t.endswith("%")
        t = t.rstrip("%").replace(",", ".")
        try:
            n = float(t)
            return (round(n / 100, 6) if pct else n), "number"
        except ValueError:
            return s, "string"
    types: dict[int, str] = {}
    rows = []
    for ligne in x["lignes"]:
        row = {}
        for i, v in enumerate(ligne):
            val, ty = conv(v)
            types[i] = ty if types.get(i, ty) == ty else "string"
            row[i] = val
        rows.append(row)
    cols = [{"key": slug(c) or f"c{i}", "label": c, "type": types.get(i, "string")} for i, c in enumerate(x["colonnes"])]
    return {"format": "atelier-table/1", "name": slug(x["titre"].split(" (")[0]), "label": x["titre"].split(" (")[0],
            "columns": cols, "rows": [{cols[i]["key"]: (v if cols[i]["type"] != "string" else str(x["lignes"][n][i]))
                                       for i, v in r.items()} for n, r in enumerate(rows)]}


def part_viz(h: dict[str, Any]) -> dict[str, Any]:
    ops = table_operations(h)
    jeux = [{"nom": f"{h['titre']} — opérations août-oct. 2026", "cle": h["cle_operations"],
             "table": atelier_table("Opérations", ops["colonnes"], ops["lignes"])}]
    for t in h["tab"]["tables"]:
        jeux.append({"nom": f"{h['titre']} — {t['nom']}", "cle": f"exemple:{h['id']}:{slug(t['nom'])}",
                     "table": atelier_table(t["nom"], t["colonnes"], t["lignes"])})
    for j in h["viz"].get("jeux_extra", []):
        src = j["source"].split(":", 1)[1]
        x = next(e for e in h["convert"]["autres"] if e["fichier"] == src)
        jeux.append({"nom": f"{h['titre']} — {j['nom']}", "cle": f"exemple:{h['id']}:{slug(j['nom'])}", "table": csv_table(x)})
    a = h["viz"]["alerte"]
    return {"format": FORMAT, "histoire": meta(h), "jeux": jeux,
            "alerte": {"nom": f"{a['nom']} — {h['titre']}", "jeu_cle": h["cle_operations"],
                       "mesure": {"field": "Débit", "agg": "sum"},
                       "filtres": [{"field": "Catégorie", "op": "eq", "values": [a["categorie"]]},
                                   {"field": "Mois", "op": "eq", "values": [MOIS[-1]]}],
                       "comparaison": "gt", "seuil": a["seuil"], "valeur_attendue": h["alerte_valeur"]}}


def part_tresorerie(h: dict[str, Any]) -> dict[str, Any]:
    t = h["tresorerie"]
    cats = {}
    for o in h["operations"]:
        cats.setdefault(o["categorie"], set()).add("revenu" if o["credit"] else "depense")
    return {"format": FORMAT, "histoire": meta(h),
            "compte": {"nom": t["compte"], "type": t.get("type", "courant"), "institution": "Banque Exemple (fictive)",
                       "solde_initial": h["solde_initial"]},
            "categories": [{"nom": c, "type": "revenu" if k == {"revenu"} else "depense"} for c, k in sorted(cats.items())],
            "operations": [{"date": o["date"], "libelle": o["libelle"], "montant": round(o["credit"] - o["debit"], 2),
                            "categorie": o["categorie"]} for o in h["operations"]],
            "budgets": {"mois": MOIS[-1], "montants": t["budgets"]}}


def part_projets(h: dict[str, Any]) -> dict[str, Any]:
    p, a = h["projets"], h["viz"]["alerte"]
    phases = []
    alerte_story = None
    for ph in p["phases"]:
        epics = []
        for e in ph["epics"]:
            stories = []
            for s in e["stories"]:
                items = [{"titre": i["titre"], "type": i.get("type", "TASK"), "statut": STATUTS[i.get("statut", "À faire")],
                          "priorite": i.get("priorite", "NORMAL"), "estime": i.get("estime"), "passe": i.get("passe"),
                          "echeance": i.get("echeance")} for i in s["items"]]
                stories.append({"titre": s["titre"], "alertes": bool(s.get("alertes")), "items": items})
                if s.get("alertes"):
                    alerte_story = s["titre"]
            epics.append({"titre": e["titre"], "stories": stories})
        phases.append({"titre": ph["titre"], "epics": epics})
    return {"format": FORMAT, "histoire": meta(h),
            "projet": {"nom": p["projet"], "description": p["description"] + " Exemple de la suite Atelier (données fictives)."},
            "phases": phases,
            "jalons": [{"titre": j["titre"], "date": j["date"], "atteint": j.get("atteint", False)} for j in p.get("jalons", [])],
            "tache_alerte": {"story": alerte_story,
                             "titre": f"Alerte « {a['nom']} » : {euros(h['alerte_valeur'])} (seuil {euros(a['seuil'])})",
                             "description": f"Alerte Atelier Viz déclenchée sur le jeu « {h['titre']} — opérations août-oct. 2026 ».\n\n"
                                            f"- Valeur mesurée : {euros(h['alerte_valeur'])}\n- Seuil : {euros(a['seuil'])}\n\n"
                                            "À analyser dans le rapport Viz.",
                             "journal": f"Créée par l'exemple « {h['titre']} », comme le ferait le workflow Nexus "
                                        f"« Alerte Viz → tâche de suivi Projets » à partir de l'alerte « {a['nom']} »."}}


def pages_wiki(h: dict[str, Any]) -> list[dict[str, Any]]:
    a = h["viz"]["alerte"]
    ordre = parcours(h)
    lignes = [f"{h['resume']}", "", "Cet exemple traverse toute la suite Atelier, avec les mêmes données d'une app à l'autre :", ""]
    lignes += [f"{i}. **{NOMS[e['app']]}** — {e['titre']}. {e['texte']}" for i, e in enumerate(ordre, 1)]
    lignes += ["", "Bilans du trimestre : [[Bilans mensuels]]."]
    pages = [{"titre": "Parcours de l'exemple", "parent": None, "icone": "🧭", "contenu": "\n".join(lignes) + "\n"},
             {"titre": "Bilans mensuels", "parent": None, "icone": "📅",
              "contenu": "Une page par mois, écrite à la clôture. Retour au [[Parcours de l'exemple]].\n"}]
    for r in h["releves"]:
        m = r["mois"]
        deb, cred = total(h["operations"], m, "debit"), total(h["operations"], m, "credit")
        cat = total(h["operations"], m, "debit", a["categorie"])
        par_cat: dict[str, float] = {}
        for o in r["operations"]:
            if o["debit"]:
                par_cat[o["categorie"]] = round(par_cat.get(o["categorie"], 0) + o["debit"], 2)
        txt = ["| Indicateur | Montant |", "|---|---:|", f"| Solde initial | {euros(r['solde_initial'])} |",
               f"| Encaissements | {euros(cred)} |", f"| Décaissements | {euros(deb)} |",
               f"| Solde final | {euros(r['solde_final'])} |", "", "## Dépenses par catégorie", "",
               "| Catégorie | Montant |", "|---|---:|"]
        txt += [f"| {c} | {euros(v)} |" for c, v in sorted(par_cat.items(), key=lambda x: -x[1])]
        txt += ["", "## Point d'attention", ""]
        if cat > a["seuil"]:
            txt.append(f"- [ ] {a['categorie']} : {euros(cat)} pour un seuil de {euros(a['seuil'])}. "
                       "Suivi dans Projets (story de suivi des budgets).")
        else:
            txt.append(f"- [x] {a['categorie']} : {euros(cat)}, sous le seuil de {euros(a['seuil'])}.")
        pages.append({"titre": f"Bilan {r['libelle']}", "parent": "Bilans mensuels", "icone": "🧾", "contenu": "\n".join(txt) + "\n"})
    for p in h["wiki"]["pages"]:
        pages.append({"titre": p["titre"], "parent": p.get("parent"), "icone": p.get("icone"), "contenu": p["contenu"]})
    return pages


def part_wiki(h: dict[str, Any]) -> dict[str, Any]:
    w = h["wiki"]
    return {"format": FORMAT, "histoire": meta(h),
            "espace": {"nom": w["espace"], "icone": w.get("icone", "📘"), "description": w["description"]},
            "pages": pages_wiki(h)}


def part_nexus(h: dict[str, Any]) -> dict[str, Any]:
    a = h["viz"]["alerte"]
    alerte_story = next(s["titre"] for p in h["projets"]["phases"] for e in p["epics"] for s in e["stories"] if s.get("alertes"))
    return {"format": FORMAT, "histoire": meta(h),
            "workflows": [{"modele": m} for m in h["nexus"]["workflows"]],
            # Tables Tab : identifiants stables de Tab (src/examples/suite.ts : tbl_ex_<histoire>_<n>, 0 = opérations)
            "references": {"tab_projet": h["tab_ids"]["projet"],
                           "tab_tables": [f"tbl_ex_{h['id']}_{i}" for i in range(1 + len(h["tab"]["tables"]))],
                           "viz_jeu_cle": h["cle_operations"],
                           "viz_alerte": f"{a['nom']} — {h['titre']}", "valeur": euros(h["alerte_valeur"]),
                           "seuil": euros(a["seuil"]), "projets_projet": h["projets"]["projet"],
                           "projets_story": alerte_story}}


PARTS = {"tab": part_tab, "viz": part_viz, "tresorerie": part_tresorerie, "nexus": part_nexus,
         "projets": part_projets, "wiki": part_wiki}


def ecrire(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--vers", help="dossier qui contient les dépôts des apps : copie exemples-suite/ dans chacun")
    args = ap.parse_args()
    dist = ICI / "dist"
    if dist.exists():
        shutil.rmtree(dist)
    histoires = [charger(n) for n in HISTOIRES]
    # Une catégorie porte le même nom dans toutes les apps (Trésorerie les partage entre comptes) : même sens partout.
    sens: dict[str, tuple[str, str]] = {}
    for h in histoires:
        for c in part_tresorerie(h)["categories"]:
            autre = sens.setdefault(c["nom"], (h["id"], c["type"]))
            if autre[1] != c["type"]:
                raise SystemExit(f"Catégorie « {c['nom']} » : {c['type']} dans {h['id']}, {autre[1]} dans {autre[0]}")
    index = {"format": FORMAT, "ordre": APPS, "apps": NOMS,
             "histoires": [{**meta(h), "parcours": parcours(h)} for h in histoires]}
    for app in APPS:
        d = dist / app / "exemples-suite"
        ecrire(d / "index.json", index)
        for h in histoires:
            part = part_convert(h, d) if app == "convert" else PARTS[app](h)
            ecrire(d / f"{h['id']}.json", part)
    for h in histoires:
        print(f"  {h['titre']:<32} {len(h['operations']):>3} opérations · alerte {euros(h['alerte_valeur'])} > {euros(h['viz']['alerte']['seuil'])}")
    print(f"→ {dist}")
    if args.vers:
        racine = Path(args.vers).expanduser()
        for app in APPS:
            depot = next((racine / n for n in DEPOTS[app] if (racine / n).is_dir()), None)
            if depot is None:
                print(f"  ! {NOMS[app]} : dépôt introuvable dans {racine}")
                continue
            cible = depot / "exemples-suite"
            if cible.exists():
                shutil.rmtree(cible)
            shutil.copytree(dist / app / "exemples-suite", cible)
            print(f"  ✓ {NOMS[app]} → {cible}")


if __name__ == "__main__":
    main()
