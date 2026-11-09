"""Boutique — une librairie-papeterie de quartier suit ses ventes, son stock et ses commandes."""

import random

from .commun import col

# Ventes journalières de la caisse par rayon, reproductibles.
_rnd = random.Random(81)
_RAYONS = {"Romans": 310, "Jeunesse": 190, "BD et mangas": 240, "Papeterie": 150, "Beaux livres": 80}
CAISSE = []
for m, jours, facteur in (("2026-08", 31, 0.75), ("2026-09", 30, 1.15), ("2026-10", 31, 1.0)):
    for j in range(1, jours + 1):
        if j % 7 == 2:  # jour de fermeture hebdomadaire
            continue
        for rayon, base in _RAYONS.items():
            f = facteur * (1.6 if (m == "2026-08" and rayon == "Papeterie" and j > 18) or (m == "2026-09" and rayon == "Papeterie" and j < 8) else 1)
            ca = round(base * f * _rnd.uniform(0.6, 1.4), 2)
            CAISSE.append([f"{j:02d}/{m[5:]}/{m[:4]}", rayon, str(max(1, int(ca / 18))), f"{ca:.2f}".replace(".", ",")])


def _ca(m: str) -> float:
    return round(sum(float(r[3].replace(",", ".")) for r in CAISSE if r[0][3:5] == m[5:]), 2)


HISTOIRE = {
    "id": "boutique-librairie",
    "titre": "Librairie Les Pages Vives",
    "sous_titre": "Ventes, stock et commandes d'une librairie-papeterie",
    "secteur": "Boutique",
    "resume": "Une librairie-papeterie de la Croix-Rousse à Lyon : caisse par rayon, stock et commandes aux "
              "distributeurs, rentrée scolaire puis préparation des fêtes ; les achats de livres d'octobre dépassent.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Lyon Croix-Rousse — 3 place de la Croix-Rousse, 69004 Lyon",
               "titulaire": "LES PAGES VIVES SARL", "compte": "Compte professionnel n° 00044556677"},
    "solde_initial": 14600.00,
    "recurrentes": [
        (1, "PRLV SEPA LOYER LOCAL COMMERCIAL GRANDE RUE", -1680, "Loyer"),
        (5, "VIR SEPA EMIS SALAIRES {mois}", -4900, "Salaires"),
        (9, "PRLV SEPA LOGICIEL DE CAISSE ET STOCK", -89, "Logiciels"),
        (12, "PRLV SEPA EDF ENTREPRISES", -146, "Énergie", 0.1),
        (28, "FRAIS TERMINAL CARTES BANCAIRES", -95, "Banque", 0.15),
    ],
    "ponctuelles": [
        ("2026-08-31", "REMISES CARTES BANCAIRES AOUT", round(_ca("2026-08") * 0.82, 2), "Ventes"),
        ("2026-08-31", "REMISE ESPECES AOUT", round(_ca("2026-08") * 0.18, 2), "Ventes"),
        ("2026-08-10", "PRLV SEPA DISTRIBUTEUR LIVRES NORD SUD", -6200, "Achats livres"),
        ("2026-08-20", "PRLV SEPA FOURNITURES SCOLAIRES CLAIREFONTAINE", -2850, "Achats papeterie"),
        ("2026-09-30", "REMISES CARTES BANCAIRES SEPTEMBRE", round(_ca("2026-09") * 0.82, 2), "Ventes"),
        ("2026-09-30", "REMISE ESPECES SEPTEMBRE", round(_ca("2026-09") * 0.18, 2), "Ventes"),
        ("2026-09-10", "PRLV SEPA DISTRIBUTEUR LIVRES NORD SUD", -9400, "Achats livres"),
        ("2026-09-18", "PRLV SEPA DIFFUSEUR BD ET MANGAS", -3100, "Achats livres"),
        ("2026-10-31", "REMISES CARTES BANCAIRES OCTOBRE", round(_ca("2026-10") * 0.82, 2), "Ventes"),
        ("2026-10-31", "REMISE ESPECES OCTOBRE", round(_ca("2026-10") * 0.18, 2), "Ventes"),
        ("2026-10-10", "PRLV SEPA DISTRIBUTEUR LIVRES NORD SUD", -8900, "Achats livres"),
        ("2026-10-17", "PRLV SEPA DIFFUSEUR BD ET MANGAS", -3600, "Achats livres"),
        ("2026-10-24", "PRLV SEPA DISTRIBUTEUR LIVRES NORD SUD BEAUX LIVRES FETES", -2700, "Achats livres"),
        ("2026-10-15", "CARTE DECORATION VITRINE FETES", -240, "Vitrine et animation"),
    ],
    "graine": 8,
    "convert": {"autres": [
        {"fichier": "caisse-par-rayon.csv", "titre": "Ventes de la caisse par rayon (CSV)",
         "description": "Export du logiciel de caisse : ventes journalières par rayon, d'août à octobre.",
         "colonnes": ["Date", "Rayon", "Articles", "Chiffre d'affaires TTC"], "lignes": CAISSE},
    ]},
    "tab": {
        "espace": "Les Pages Vives",
        "projet": "Boutique 2026",
        "tables": [
            {"nom": "Stock et commandes",
             "colonnes": [col("Référence", mapping="entity_title"), col("Rayon", "select", choices=list(_RAYONS)),
                          col("En stock", "number"), col("Seuil", "number"),
                          col("À commander", "formula", formula="=MAX(0,D1*2-C1)", format="number"),
                          col("Fournisseur"),
                          col("Commande", "select", choices=["À faire", "En cours", "Terminée"], mapping="workflow_state"),
                          col("Livraison prévue", "date", mapping="due_date")],
             "lignes": [
                 {"Référence": "Prix Goncourt 2026 (roman)", "Rayon": "Romans", "En stock": 4, "Seuil": 15, "Fournisseur": "Nord Sud", "Commande": "En cours", "Livraison prévue": "2026-11-06"},
                 {"Référence": "Agenda scolaire 2026-2027", "Rayon": "Papeterie", "En stock": 22, "Seuil": 10, "Fournisseur": "Clairefontaine", "Commande": "Terminée", "Livraison prévue": "2026-08-20"},
                 {"Référence": "Manga « Les Marées » tome 12", "Rayon": "BD et mangas", "En stock": 3, "Seuil": 12, "Fournisseur": "Diffuseur BD", "Commande": "À faire", "Livraison prévue": "2026-11-13"},
                 {"Référence": "Album jeunesse « Le Renard de neige »", "Rayon": "Jeunesse", "En stock": 18, "Seuil": 8, "Fournisseur": "Nord Sud", "Commande": "Terminée", "Livraison prévue": "2026-10-24"},
                 {"Référence": "Beau livre « Lyon vu du ciel »", "Rayon": "Beaux livres", "En stock": 6, "Seuil": 6, "Fournisseur": "Nord Sud", "Commande": "À faire", "Livraison prévue": "2026-11-20"},
                 {"Référence": "Carnets kraft A5 (lot de 3)", "Rayon": "Papeterie", "En stock": 40, "Seuil": 15, "Fournisseur": "Clairefontaine", "Commande": "Terminée", "Livraison prévue": "2026-09-02"},
             ]},
        ],
    },
    "viz": {"alerte": {"nom": "Achats de livres du mois", "categorie": "Achats livres", "seuil": 13000},
            "jeux_extra": [{"nom": "Caisse par rayon", "source": "convert:caisse-par-rayon.csv"}]},
    "tresorerie": {"compte": "Compte pro Les Pages Vives", "type": "courant",
                   "budgets": {"Achats livres": 13000, "Achats papeterie": 1500, "Vitrine et animation": 300,
                               "Énergie": 200, "Logiciels": 100}},
    "projets": {
        "projet": "Fêtes de fin d'année 2026 — Les Pages Vives",
        "description": "Préparer la saison des fêtes : commandes, vitrine, animations en boutique.",
        "phases": [
            {"titre": "Préparation des fêtes", "epics": [{"titre": "Novembre-décembre", "stories": [
                {"titre": "Commandes et vitrine", "items": [
                    {"titre": "Commander les beaux livres des fêtes", "statut": "Terminée", "echeance": "2026-10-24"},
                    {"titre": "Vitrine d'hiver", "statut": "En cours", "estime": 10, "passe": 4, "echeance": "2026-11-20"},
                    {"titre": "Séance de dédicaces jeunesse (samedi 12 décembre)", "statut": "À faire", "echeance": "2026-12-12"},
                    {"titre": "Recruter un renfort pour décembre", "statut": "En cours", "echeance": "2026-11-15"},
                ]},
                {"titre": "Suivi des budgets", "alertes": True, "items": []},
            ]}]},
        ],
        "jalons": [{"titre": "Rentrée scolaire bouclée", "date": "2026-09-15", "atteint": True},
                   {"titre": "Ouverture des dimanches de décembre", "date": "2026-12-06", "atteint": False}],
    },
    "wiki": {
        "espace": "Les Pages Vives", "icone": "📚",
        "description": "Procédures de la boutique : caisse, commandes, inventaire.",
        "pages": [
            {"titre": "Clôture de caisse", "icone": "🧮", "contenu": """Chaque soir :
1. Compter le fond de caisse (150 €) et les espèces.
2. Éditer le ticket Z ; vérifier l'écart avec le logiciel (tolérance 2 €).
3. Remise d'espèces à la banque le dernier jour du mois.

L'export *Ventes de la caisse par rayon* se convertit dans Convert, puis part dans Viz.
"""},
            {"titre": "Commandes aux distributeurs", "icone": "📦", "contenu": """- Nord Sud (livres) : commande le lundi, livraison le jeudi suivant ; office mensuel le 10.
- Diffuseur BD : nouveautés le mercredi.
- Clairefontaine (papeterie) : deux grosses commandes par an, juillet et janvier.

Règle : commander quand le stock passe sous le seuil (colonne *À commander* dans Tab, table *Stock et commandes*). Voir aussi [[Inventaire annuel]].
"""},
            {"titre": "Inventaire annuel", "icone": "🗃️", "contenu": """Le 31 décembre après fermeture. Prévoir deux personnes, une demi-journée. Écarts au-delà de 1 % à expliquer.
"""},
        ],
    },
    "nexus": {"workflows": ["convert-derniere-conversion-tab-viz", "viz-alerte-tache-projets"]},
}
