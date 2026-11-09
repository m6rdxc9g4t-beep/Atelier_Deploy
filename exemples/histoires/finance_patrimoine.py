"""Finance — une holding familiale suit son portefeuille et son allocation."""

from .commun import col

HISTOIRE = {
    "id": "finance-patrimoine",
    "titre": "Lemaire Patrimoine",
    "sous_titre": "Portefeuille et allocation d'une holding familiale",
    "secteur": "Finance",
    "resume": "La holding de la famille Lemaire place sa trésorerie : achats d'ETF, dividendes, comité mensuel, "
              "allocation cible ; les frais de courtage d'octobre dépassent l'enveloppe après un rééquilibrage.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Bordeaux Tourny — 1 allées de Tourny, 33000 Bordeaux",
               "titulaire": "LEMAIRE PATRIMOINE SAS", "compte": "Compte courant n° 00055667788"},
    "solde_initial": 212400.00,
    "recurrentes": [
        (5, "PRLV SEPA HONORAIRES CABINET COMPTABLE AQUITAINE", -480, "Honoraires comptables"),
        (25, "VIR SEPA RECU LOYER BUREAUX SCI CHARTRONS", 3600, "Loyers perçus"),
        (28, "FRAIS TENUE DE COMPTE", -30, "Banque"),
    ],
    "ponctuelles": [
        ("2026-08-04", "ACHAT ETF MSCI WORLD 120 PARTS", -12840, "Achats de titres"),
        ("2026-08-04", "COMMISSION COURTAGE ORDRE BOURSE", -38.52, "Frais de courtage"),
        ("2026-08-18", "DIVIDENDE TOTALENERGIES 400 ACTIONS", 316.80, "Dividendes"),
        ("2026-08-27", "SOUSCRIPTION SCPI RENDEMENT PIERRE 25 PARTS", -6250, "Achats de titres"),
        ("2026-09-02", "ACHAT OBLIGATION ETAT 2032 10000 NOMINAL", -9870, "Achats de titres"),
        ("2026-09-02", "COMMISSION COURTAGE ORDRE BOURSE", -29.61, "Frais de courtage"),
        ("2026-09-15", "COUPON OBLIGATION EDF 2029", 412.50, "Coupons"),
        ("2026-09-22", "DIVIDENDE SANOFI 250 ACTIONS", 990, "Dividendes"),
        ("2026-10-01", "VENTE ETF S&P 500 80 PARTS REEQUILIBRAGE", 41280, "Ventes de titres"),
        ("2026-10-01", "COMMISSION COURTAGE ORDRE BOURSE", -123.84, "Frais de courtage"),
        ("2026-10-02", "ACHAT ETF EURO STOXX 50 300 PARTS", -15360, "Achats de titres"),
        ("2026-10-02", "COMMISSION COURTAGE ORDRE BOURSE", -46.08, "Frais de courtage"),
        ("2026-10-03", "ACHAT ETF OBLIGATIONS EURO 200 PARTS", -21900, "Achats de titres"),
        ("2026-10-03", "COMMISSION COURTAGE ORDRE BOURSE", -65.70, "Frais de courtage"),
        ("2026-10-15", "DROITS DE GARDE COMPTE-TITRES T3", -186, "Frais de courtage"),
        ("2026-10-20", "DIVIDENDE AIR LIQUIDE 150 ACTIONS", 495, "Dividendes"),
    ],
    "graine": 5,
    "convert": {"autres": [
        {"fichier": "operations-compte-titres.csv", "titre": "Opérations du compte-titres (CSV)",
         "description": "Export du courtier : ordres, quantités, cours, frais et montant net.",
         "colonnes": ["Date", "Opération", "Titre", "Quantité", "Cours", "Frais", "Montant net"],
         "lignes": [["04/08/2026", "Achat", "ETF MSCI World", "120", "107,00", "38,52", "-12878,52"],
                    ["02/09/2026", "Achat", "OAT 2032", "10000", "98,70 %", "29,61", "-9899,61"],
                    ["01/10/2026", "Vente", "ETF S&P 500", "80", "516,00", "123,84", "41156,16"],
                    ["02/10/2026", "Achat", "ETF Euro Stoxx 50", "300", "51,20", "46,08", "-15406,08"],
                    ["03/10/2026", "Achat", "ETF Obligations Euro", "200", "109,50", "65,70", "-21965,70"]]},
    ]},
    "tab": {
        "espace": "Lemaire Patrimoine",
        "projet": "Allocation 2026",
        "tables": [
            {"nom": "Allocation cible",
             "colonnes": [col("Classe d'actifs", mapping="entity_title"), col("Cible", "percent"),
                          col("Réelle au 30/09", "percent"), col("Réelle au 31/10", "percent"),
                          col("Écart", "formula", formula="=D1-B1", format="percent"),
                          col("Valeur au 31/10", "currency")],
             "lignes": [
                 {"Classe d'actifs": "Actions monde", "Cible": 0.40, "Réelle au 30/09": 0.49, "Réelle au 31/10": 0.42, "Valeur au 31/10": 302400},
                 {"Classe d'actifs": "Obligations", "Cible": 0.30, "Réelle au 30/09": 0.24, "Réelle au 31/10": 0.29, "Valeur au 31/10": 208800},
                 {"Classe d'actifs": "Immobilier (SCPI, bureaux)", "Cible": 0.20, "Réelle au 30/09": 0.19, "Réelle au 31/10": 0.19, "Valeur au 31/10": 136800},
                 {"Classe d'actifs": "Trésorerie", "Cible": 0.10, "Réelle au 30/09": 0.08, "Réelle au 31/10": 0.10, "Valeur au 31/10": 72000},
             ]},
        ],
    },
    "viz": {"alerte": {"nom": "Frais de courtage du mois", "categorie": "Frais de courtage", "seuil": 250}},
    "tresorerie": {"compte": "Compte courant Lemaire Patrimoine", "type": "courant",
                   "budgets": {"Frais de courtage": 250, "Honoraires comptables": 500, "Banque": 40}},
    "projets": {
        "projet": "Rééquilibrage 2026 — Lemaire Patrimoine",
        "description": "Ramener le portefeuille à l'allocation cible votée par le comité de septembre.",
        "phases": [
            {"titre": "Rééquilibrage", "epics": [{"titre": "Comité de septembre", "stories": [
                {"titre": "Ordres à passer", "items": [
                    {"titre": "Vendre 80 parts d'ETF S&P 500", "statut": "Terminée", "echeance": "2026-10-01"},
                    {"titre": "Acheter 300 parts d'ETF Euro Stoxx 50", "statut": "Terminée", "echeance": "2026-10-02"},
                    {"titre": "Acheter 200 parts d'ETF Obligations Euro", "statut": "Terminée", "echeance": "2026-10-03"},
                    {"titre": "Comparer les frais de deux autres courtiers", "statut": "À faire", "echeance": "2026-11-30"},
                ]},
                {"titre": "Suivi des budgets", "alertes": True, "items": []},
            ]}]},
        ],
        "jalons": [{"titre": "Allocation cible atteinte", "date": "2026-10-31", "atteint": True},
                   {"titre": "Comité de décembre", "date": "2026-12-10", "atteint": False}],
    },
    "wiki": {
        "espace": "Lemaire Patrimoine", "icone": "📈",
        "description": "Politique d'investissement et comptes rendus du comité.",
        "pages": [
            {"titre": "Politique d'investissement", "icone": "🧭", "contenu": """Horizon 10 ans, risque modéré.

| Classe d'actifs | Cible | Marge |
|---|---:|---:|
| Actions monde | 40 % | ± 5 pts |
| Obligations | 30 % | ± 5 pts |
| Immobilier | 20 % | ± 5 pts |
| Trésorerie | 10 % | ± 3 pts |

Un écart au-delà de la marge déclenche un rééquilibrage au comité suivant. Suivi de l'allocation : table *Allocation cible* dans Tab.
"""},
            {"titre": "Comité du 24 septembre 2026", "icone": "🗳️", "contenu": """Actions à 49 % pour une cible de 40 % : rééquilibrage voté.

- [x] Vendre 80 parts d'ETF S&P 500
- [x] Racheter de l'Euro Stoxx 50 et des obligations euro
- [ ] Revoir les frais de courtage, élevés sur les gros ordres

Voir la [[Politique d'investissement]].
"""},
        ],
    },
    "nexus": {"workflows": ["convert-derniere-conversion-tab-viz", "viz-alerte-tache-projets"]},
}
