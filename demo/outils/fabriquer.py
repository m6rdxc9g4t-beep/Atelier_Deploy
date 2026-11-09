"""Fabrique les fichiers d'exemple du kit de démo à partir de donnees/studio-garance.json.

Produit dans demo/donnees/ :
- releve_2026-08.pdf, releve_2026-09.pdf, releve_2026-10.pdf : relevés « Débit / Crédit » sur deux pages,
  au format que lit Atelier Convert (même mise en page que ses exemples : en-tête de colonnes, ancien et
  nouveau solde, « À reporter » entre les pages) ;
- operations_2026-08_2026-10.csv : les trois mois en CSV français (« ; », virgule décimale, JJ/MM/AAAA),
  importable dans Trésorerie (import CSV) ou dans Tab (import CSV).

Les fichiers produits sont versionnés : à relancer seulement si le jeu de données change.

    python3 -m venv /tmp/fab && /tmp/fab/bin/pip install reportlab
    /tmp/fab/bin/python demo/outils/fabriquer.py
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen.canvas import Canvas

DEMO = Path(__file__).resolve().parents[1]
DONNEES = DEMO / "donnees"


def fr(amount: float) -> str:
    """1234.5 → « 1 234,50 »."""
    whole, dec = f"{abs(amount):,.2f}".split(".")
    return whole.replace(",", " ") + "," + dec


def jjmm(iso: str) -> str:
    return f"{iso[8:10]}/{iso[5:7]}"


def jjmmaaaa(iso: str) -> str:
    return f"{iso[8:10]}/{iso[5:7]}/{iso[0:4]}"


def releve_pdf(path: Path, banque: dict, releve: dict) -> None:
    ops = releve["operations"]
    debit = round(sum(o["debit"] for o in ops), 2)
    credit = round(sum(o["credit"] for o in ops), 2)
    first, last = ops[0]["date"][:8] + "01", ops[-1]["date"]
    # Dernier jour du mois et veille du premier jour, pour les libellés de solde.
    mois = int(releve["mois"][5:7])
    fin = {8: "31", 9: "30", 10: "31", 11: "30", 12: "31"}.get(mois, "30")
    veille = {8: "31/07", 9: "31/08", 10: "30/09", 11: "31/10", 12: "30/11"}.get(mois, "")
    annee = releve["mois"][:4]

    c = Canvas(str(path), pagesize=A4)
    c.setTitle(f"Relevé {releve['libelle']} — {banque['titulaire']} (fictif)")
    width, height = A4

    def header(page: int) -> float:
        c.setFont("Helvetica-Bold", 14)
        c.drawString(40, height - 50, banque["nom"])
        c.setFont("Helvetica", 9)
        c.drawString(40, height - 64, banque["agence"])
        c.setFont("Helvetica-Bold", 11)
        c.drawString(40, height - 95, "RELEVÉ DE COMPTE PROFESSIONNEL")
        c.setFont("Helvetica", 9)
        c.drawString(40, height - 109, f"{banque['titulaire']} — {banque['compte']}")
        c.drawString(40, height - 121, f"Période du {jjmmaaaa(first)} au {fin}/{releve['mois'][5:7]}/{annee}")
        c.drawRightString(width - 40, height - 95, f"Page {page}/2")
        y = height - 150
        c.setFont("Helvetica-Bold", 9)
        c.drawString(40, y, "Date")
        c.drawString(85, y, "Valeur")
        c.drawString(135, y, "Nature des opérations")
        c.drawRightString(470, y, "Débit")
        c.drawRightString(555, y, "Crédit")
        c.line(40, y - 4, width - 40, y - 4)
        c.setFont("Helvetica", 9)
        return y - 18

    y = header(1)
    c.drawString(135, y, f"Ancien solde au {veille}/{annee}")
    c.drawRightString(555, y, fr(releve["solde_initial"]))
    y -= 18
    cut = (len(ops) + 1) // 2 + 1
    for i, o in enumerate(ops):
        if i == cut:
            c.setFont("Helvetica-Oblique", 8)
            c.drawString(135, y - 4, "À reporter")
            c.showPage()
            y = header(2)
        c.drawString(40, y, jjmm(o["date"]))
        c.drawString(85, y, jjmm(o["date"]))
        c.drawString(135, y, o["libelle"])
        if o["debit"]:
            c.drawRightString(470, y, fr(o["debit"]))
        if o["credit"]:
            c.drawRightString(555, y, fr(o["credit"]))
        y -= 16
    c.line(40, y + 8, width - 40, y + 8)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(135, y - 4, "Total des opérations")
    c.drawRightString(470, y - 4, fr(debit))
    c.drawRightString(555, y - 4, fr(credit))
    c.drawString(135, y - 20, f"Nouveau solde au {jjmmaaaa(last[:8] + fin)} créditeur")
    c.drawRightString(555, y - 20, fr(releve["solde_final"]))
    c.setFont("Helvetica", 7)
    c.drawString(40, 40, "Document fictif — kit de démo de la suite Atelier (Studio Garance). Aucune donnée réelle.")
    c.save()


def operations_csv(path: Path, releves: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Date", "Libellé", "Débit", "Crédit", "Catégorie"])
        for r in releves:
            for o in r["operations"]:
                w.writerow([
                    jjmmaaaa(o["date"]),
                    o["libelle"],
                    fr(o["debit"]) if o["debit"] else "",
                    fr(o["credit"]) if o["credit"] else "",
                    o["categorie"],
                ])


def main() -> None:
    data = json.loads((DONNEES / "studio-garance.json").read_text(encoding="utf-8"))
    for r in data["releves"]:
        releve_pdf(DONNEES / r["fichier"], data["banque"], r)
    first, last = data["releves"][0]["mois"], data["releves"][-1]["mois"]
    operations_csv(DONNEES / f"operations_{first}_{last}.csv", data["releves"])
    print("Fichiers écrits dans", DONNEES)


if __name__ == "__main__":
    main()
