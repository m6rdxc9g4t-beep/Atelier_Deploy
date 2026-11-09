"""Outils communs aux histoires d'exemple de la suite Atelier.

Une histoire est un dictionnaire (voir `Histoire` ci-dessous) écrit dans un module de ce dossier. Le générateur
(`exemples/generer.py`) en tire la part de chaque app. Les montants sont en euros, les dates au format ISO.

Toutes les données sont fictives : noms de personnes, d'entreprises, de clients et de banques inventés.
"""

from __future__ import annotations

import random
from datetime import date
from typing import Any, TypedDict

MOIS = ["2026-08", "2026-09", "2026-10"]
LIBELLES_MOIS = {"2026-08": "août 2026", "2026-09": "septembre 2026", "2026-10": "octobre 2026"}
FIN_MOIS = {"2026-08": 31, "2026-09": 30, "2026-10": 31}


class Operation(TypedDict):
    date: str
    libelle: str
    debit: float
    credit: float
    categorie: str


def releves(solde_initial: float, operations: list[Operation]) -> list[dict[str, Any]]:
    """Regroupe les opérations par mois avec soldes initial et final (un relevé par mois)."""
    out = []
    solde = round(solde_initial, 2)
    for m in MOIS:
        ops = sorted((o for o in operations if o["date"].startswith(m)), key=lambda o: (o["date"], -o["credit"]))
        ouverture = solde
        for o in ops:
            solde = round(solde - o["debit"] + o["credit"], 2)
        out.append({"mois": m, "libelle": LIBELLES_MOIS[m], "solde_initial": ouverture, "solde_final": solde,
                    "operations": ops})
    return out


def operations(recurrentes: list[tuple], ponctuelles: list[tuple], graine: int) -> list[Operation]:
    """Opérations d'août à octobre 2026.

    recurrentes : (jour, libellé, montant, catégorie[, variation]) chaque mois ; montant < 0 = débit.
                  « {mois} » dans le libellé devient le mois en lettres ; variation (0,1 = ±10 %) rend le
                  montant différent chaque mois, de façon reproductible.
    ponctuelles : (date ISO, libellé, montant, catégorie).
    """
    rnd = random.Random(graine)
    out: list[Operation] = []
    for m in MOIS:
        for r in recurrentes:
            jour, libelle, montant, cat = r[:4]
            var = r[4] if len(r) > 4 else 0
            if var:
                montant = round(montant * (1 + rnd.uniform(-var, var)), 2)
            j = min(jour, FIN_MOIS[m])
            out.append(_op(f"{m}-{j:02d}", libelle.replace("{mois}", LIBELLES_MOIS[m].split()[0].upper()), montant, cat))
    for d, libelle, montant, cat in ponctuelles:
        out.append(_op(d, libelle, montant, cat))
    return sorted(out, key=lambda o: (o["date"], -o["credit"]))


def _op(d: str, libelle: str, montant: float, cat: str) -> Operation:
    date.fromisoformat(d)  # valide la date
    montant = round(montant, 2)
    return {"date": d, "libelle": libelle, "debit": -montant if montant < 0 else 0.0,
            "credit": montant if montant > 0 else 0.0, "categorie": cat}


def total(ops: list[Operation], mois: str, champ: str, categorie: str | None = None) -> float:
    return round(sum(o[champ] for o in ops if o["date"].startswith(mois)
                     and (categorie is None or o["categorie"] == categorie)), 2)


def euros(v: float) -> str:
    whole, dec = f"{abs(v):,.2f}".split(".")
    return ("−" if v < 0 else "") + whole.replace(",", " ") + "," + dec + " €"


# ─── Colonnes de table (Tab, Viz) ─────────────────────────────────────────────────────────────────

def col(label: str, type_: str = "text", **extra: Any) -> dict[str, Any]:
    """Colonne d'une table d'exemple.

    type_ : text, number, currency, percent, date, select, checkbox, formula.
    extra : choices (liste de libellés, pour select), mapping (rôle atelier : entity_title, workflow_state,
            due_date, start_date, assignee, financial_ht, time_spent, item_type, description), formula (=…),
            format (résultat d'une formule : currency, number, percent).
    """
    return {"label": label, "type": type_, **extra}


# Les 8 statuts communs de la suite (docs/SUITE.md §1.4) : libellé affiché → code de Projets.
STATUTS = {"À faire": "OPEN", "En cours": "IN_PROGRESS", "En revue": "IN_REVIEW", "En attente": "ON_HOLD",
           "Bloquée": "BLOCKED", "Résolue": "RESOLVED", "Terminée": "CLOSED", "Rejetée": "REJECTED"}
