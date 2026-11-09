"""Freelance data — un consultant data indépendant suit ses missions, son temps et sa trésorerie."""

from .commun import col

MISSIONS = [  # client, mission, TJM, jours prévus, jours faits, statut, fin
    ("Coopérative Laitière du Jura", "Tableau de bord de la collecte de lait", 620, 18, 15, "En cours", "2026-11-14"),
    ("Mutuelle des Artisans de Bourgogne", "Modèle de prévision des résiliations", 680, 12, 12, "Terminée", "2026-09-30"),
    ("Réseau de Librairies Oxalis", "Audit de la qualité des données clients", 590, 6, 4, "En cours", "2026-11-07"),
    ("Agence Orbe", "Formation SQL pour l'équipe marketing", 750, 2, 0, "À faire", "2026-11-20"),
]

HISTOIRE = {
    "id": "freelance-data",
    "titre": "Consultant data freelance",
    "sous_titre": "Missions, temps facturé et trésorerie d'un indépendant",
    "secteur": "Freelance",
    "resume": "Julien Morel, consultant data indépendant à Dijon : missions suivies dans Tab et Projets, temps passé, "
              "factures payées via une plateforme, provisions URSSAF ; ses frais de logiciels dérapent en octobre.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Dijon Darcy — 9 place Darcy, 21000 Dijon",
               "titulaire": "JULIEN MOREL — EI", "compte": "Compte professionnel n° 00033221144"},
    "solde_initial": 9120.00,
    "recurrentes": [
        (3, "PRLV SEPA COWORKING LA FABRIQUE DIJON", -290, "Coworking"),
        (6, "PRLV SEPA FREE PRO", -39.99, "Télécom"),
        (12, "PRLV SEPA URSSAF COTISATIONS", -1180, "Cotisations sociales", 0.08),
        (14, "VIR SEPA EMIS LIVRET PROVISION IMPOTS", -900, "Provision impôts"),
        (20, "PRLV SEPA ASSURANCE RC PRO HISCOX", -46.50, "Assurances"),
        (28, "FRAIS TENUE DE COMPTE", -8, "Banque"),
    ],
    "ponctuelles": [
        ("2026-08-04", "VIR SEPA RECU PLATEFORME FREELANCE MUTUELLE ARTISANS F-2026-021", 4080, "Honoraires"),
        ("2026-08-25", "VIR SEPA RECU COOPERATIVE LAITIERE JURA F-2026-022", 3720, "Honoraires"),
        ("2026-08-09", "PRLV SEPA GOOGLE WORKSPACE", -13.60, "Logiciels"),
        ("2026-08-17", "CARTE SNCF DIJON BESANCON", -42, "Déplacements"),
        ("2026-09-03", "VIR SEPA RECU PLATEFORME FREELANCE MUTUELLE ARTISANS F-2026-024", 4080, "Honoraires"),
        ("2026-09-24", "VIR SEPA RECU COOPERATIVE LAITIERE JURA F-2026-025", 3720, "Honoraires"),
        ("2026-09-09", "PRLV SEPA GOOGLE WORKSPACE", -13.60, "Logiciels"),
        ("2026-09-15", "CARTE SNCF DIJON BESANCON", -84, "Déplacements"),
        ("2026-09-21", "CARTE FNAC LIVRE STATISTIQUES", -54.90, "Formation"),
        ("2026-10-02", "VIR SEPA RECU PLATEFORME FREELANCE MUTUELLE ARTISANS F-2026-027 SOLDE", 2720, "Honoraires"),
        ("2026-10-27", "VIR SEPA RECU COOPERATIVE LAITIERE JURA F-2026-028", 3100, "Honoraires"),
        ("2026-10-09", "PRLV SEPA GOOGLE WORKSPACE", -13.60, "Logiciels"),
        ("2026-10-11", "CARTE JETBRAINS ABONNEMENT ANNUEL", -289, "Logiciels"),
        ("2026-10-14", "CARTE TABLEAU CLOUD LICENCE CREATOR", -840, "Logiciels"),
        ("2026-10-16", "CARTE SNCF DIJON BESANCON", -84, "Déplacements"),
        ("2026-10-19", "CARTE FNAC LIVRE STATISTIQUES", -48.50, "Formation"),
    ],
    "graine": 4,
    "convert": {"autres": [
        {"fichier": "paiements-plateforme.csv", "titre": "Paiements de la plateforme freelance (CSV)",
         "description": "Relevé des paiements reçus : facture, client, montant brut, commission, net versé.",
         "colonnes": ["Date", "Facture", "Client", "Brut HT", "Commission", "Net versé"],
         "lignes": [["04/08/2026", "F-2026-021", "Mutuelle des Artisans de Bourgogne", "4250,00", "170,00", "4080,00"],
                    ["03/09/2026", "F-2026-024", "Mutuelle des Artisans de Bourgogne", "4250,00", "170,00", "4080,00"],
                    ["02/10/2026", "F-2026-027", "Mutuelle des Artisans de Bourgogne", "2833,33", "113,33", "2720,00"]]},
    ]},
    "tab": {
        "espace": "Julien Morel — freelance",
        "projet": "Missions 2026",
        "tables": [
            {"nom": "Missions",
             "colonnes": [col("Mission", mapping="entity_title"), col("Client"), col("TJM", "currency"),
                          col("Jours prévus", "number"), col("Jours faits", "number", mapping="time_spent"),
                          col("Reste à facturer", "formula", formula="=C1*(D1-E1)", format="currency"),
                          col("Statut", "select", choices=["À faire", "En cours", "Terminée"], mapping="workflow_state"),
                          col("Fin", "date", mapping="due_date")],
             "lignes": [{"Mission": mi, "Client": cl, "TJM": t, "Jours prévus": jp, "Jours faits": jf, "Statut": s, "Fin": f}
                        for cl, mi, t, jp, jf, s, f in MISSIONS]},
        ],
    },
    "viz": {"alerte": {"nom": "Logiciels du mois", "categorie": "Logiciels", "seuil": 300}},
    "tresorerie": {"compte": "Compte pro Julien Morel", "type": "courant",
                   "budgets": {"Logiciels": 300, "Déplacements": 150, "Formation": 80, "Coworking": 300,
                               "Cotisations sociales": 1400}},
    "projets": {
        "projet": "Missions 2026 — Julien Morel",
        "description": "Missions de conseil data : un epic par client, le temps passé saisi chaque semaine.",
        "phases": [
            {"titre": "Missions en cours", "epics": [
                {"titre": "Coopérative Laitière du Jura", "stories": [
                    {"titre": "Tableau de bord de la collecte de lait", "items": [
                        {"titre": "Modèle de données collecte (producteurs, tournées)", "statut": "Terminée", "estime": 24, "passe": 26},
                        {"titre": "Indicateurs qualité du lait (TB, TP, cellules)", "statut": "Terminée", "estime": 32, "passe": 30},
                        {"titre": "Tableau de bord par tournée", "statut": "En cours", "estime": 40, "passe": 28, "echeance": "2026-11-14"},
                        {"titre": "Recette avec le service qualité", "statut": "À faire", "estime": 8, "echeance": "2026-11-14"},
                    ]},
                ]},
                {"titre": "Réseau de Librairies Oxalis", "stories": [
                    {"titre": "Audit qualité des données clients", "items": [
                        {"titre": "Profilage des fichiers clients des 9 librairies", "statut": "Terminée", "estime": 12, "passe": 14},
                        {"titre": "Doublons et adresses invalides : règles de nettoyage", "statut": "En cours", "estime": 16, "passe": 10},
                        {"titre": "Restitution et score de qualité", "statut": "À faire", "estime": 8, "echeance": "2026-11-07"},
                    ]},
                ]},
            ]},
            {"titre": "Gestion de l'activité", "epics": [{"titre": "Administratif", "stories": [
                {"titre": "Suivi des budgets", "alertes": True, "items": [
                    {"titre": "Déclarer le chiffre d'affaires d'octobre à l'URSSAF", "statut": "À faire", "echeance": "2026-11-30"},
                ]},
            ]}]},
        ],
        "jalons": [{"titre": "Livraison du tableau de bord collecte", "date": "2026-11-14", "atteint": False}],
    },
    "wiki": {
        "espace": "Julien Morel — freelance", "icone": "📊",
        "description": "Fiches missions, modèles et règles de gestion de l'activité.",
        "pages": [
            {"titre": "Fiche mission — Coopérative Laitière du Jura", "icone": "🥛", "contenu": """**Objet** : tableau de bord de la collecte de lait (18 jours, TJM 620 €).

**Contacts** : service qualité, responsable des tournées.

## Livrables
- [x] Modèle de données collecte
- [x] Indicateurs qualité (TB, TP, cellules)
- [ ] Tableau de bord par tournée
- [ ] Recette

Temps passé : projet *Missions 2026* dans Projets. Facturation : voir [[Règles de facturation]].
"""},
            {"titre": "Règles de facturation", "icone": "🧾", "contenu": """- Facture à la fin de chaque mois, sur les jours réellement passés (colonne *Jours faits* dans Tab).
- Paiement à 30 jours ; les clients passés par la plateforme paient via elle (commission de 4 %).
- Provision : 25 % des encaissements pour l'URSSAF, 900 € par mois pour l'impôt.
"""},
            {"titre": "Outils et abonnements", "icone": "🧰", "contenu": """| Outil | Coût | Échéance |
|---|---:|---|
| Google Workspace | 13,60 €/mois | mensuel |
| JetBrains (DataGrip) | 289 €/an | octobre |
| Tableau Creator | 840 €/an | octobre |

Octobre concentre les renouvellements annuels : le budget *Logiciels* du mois est dépassé.
"""},
        ],
    },
    "nexus": {"workflows": ["projets-temps-hebdo-viz", "viz-alerte-tache-projets"]},
}
