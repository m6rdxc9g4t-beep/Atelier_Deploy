"""Assurance — un cabinet de courtage suit son portefeuille de contrats, les sinistres et ses renouvellements."""

from .commun import col

CONTRATS = [  # client, branche, assureur, prime annuelle, échéance, sinistres 2026, statut renouvellement
    ("Boulangerie Fournil des Halles", "Multirisque pro", "Assureur Atlantique", 2860, "2026-12-31", 0, "À faire"),
    ("Transports Mercier", "Flotte automobile", "Assureur Atlantique", 18400, "2026-12-31", 14200, "En cours"),
    ("Cabinet dentaire Rive Gauche", "RC professionnelle", "Mutuelle du Midi", 1940, "2027-01-31", 0, "À faire"),
    ("SCI Les Tilleuls", "Propriétaire non occupant", "Mutuelle du Midi", 1120, "2026-11-30", 3600, "En cours"),
    ("Garage Central Perrin", "Multirisque pro", "Assureur Atlantique", 4310, "2026-12-31", 0, "À faire"),
    ("Taxis Rive Droite", "Flotte automobile", "Compagnie Horizon", 9650, "2026-11-30", 8900, "En revue"),
    ("Crèche Les Petits Pas", "RC et dommages", "Compagnie Horizon", 3280, "2027-03-31", 450, "À faire"),
]

SINISTRES = [  # date, client, branche, nature, montant estimé, statut
    ["03/08/2026", "Transports Mercier", "Flotte automobile", "Collision poids lourd", "6800,00", "Clos"],
    ["19/08/2026", "Taxis Rive Droite", "Flotte automobile", "Bris de glace", "650,00", "Clos"],
    ["02/09/2026", "SCI Les Tilleuls", "Propriétaire non occupant", "Dégât des eaux", "3600,00", "En cours"],
    ["11/09/2026", "Taxis Rive Droite", "Flotte automobile", "Accrochage", "2100,00", "Clos"],
    ["28/09/2026", "Crèche Les Petits Pas", "RC et dommages", "Vol de matériel", "450,00", "Clos"],
    ["07/10/2026", "Transports Mercier", "Flotte automobile", "Sortie de route", "7400,00", "En cours"],
    ["15/10/2026", "Taxis Rive Droite", "Flotte automobile", "Collision", "6150,00", "En cours"],
]

HISTOIRE = {
    "id": "assurance-courtage",
    "titre": "Arpège Courtage",
    "sous_titre": "Portefeuille, sinistres et renouvellements d'un cabinet de courtage",
    "secteur": "Assurance",
    "resume": "Le cabinet Arpège, à Toulouse, gère 7 clients professionnels : primes, commissions, sinistres "
              "déclarés ; la flotte automobile se dégrade et les frais juridiques dépassent leur budget en octobre.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Toulouse Capitole — 6 rue du Taur, 31000 Toulouse",
               "titulaire": "ARPEGE COURTAGE SARL", "compte": "Compte professionnel n° 00011998877"},
    "solde_initial": 31250.00,
    "recurrentes": [
        (2, "PRLV SEPA LOYER BUREAUX CAPITOLE", -1350, "Locaux"),
        (5, "VIR SEPA EMIS SALAIRES {mois}", -7400, "Salaires"),
        (10, "VIR SEPA RECU ASSUREUR ATLANTIQUE COMMISSIONS {mois}", 4280, "Commissions", 0.06),
        (12, "VIR SEPA RECU MUTUELLE DU MIDI COMMISSIONS {mois}", 1460, "Commissions", 0.06),
        (15, "VIR SEPA RECU COMPAGNIE HORIZON COMMISSIONS {mois}", 2310, "Commissions", 0.06),
        (18, "PRLV SEPA LOGICIEL COURTAGE ASSURLINK", -420, "Logiciels"),
        (24, "PRLV SEPA RC PRO COURTIER ET GARANTIE FINANCIERE", -210, "Assurances"),
        (28, "FRAIS TENUE DE COMPTE", -22, "Banque"),
    ],
    "ponctuelles": [
        ("2026-08-21", "VIR SEPA EMIS CABINET EXPERTISE AUTO SUD", -380, "Frais juridiques"),
        ("2026-09-08", "CARTE SALON PATRIMOINE ET ASSURANCE TOULOUSE", -650, "Prospection"),
        ("2026-09-25", "VIR SEPA EMIS CABINET EXPERTISE AUTO SUD", -420, "Frais juridiques"),
        ("2026-10-09", "VIR SEPA EMIS MAITRE ROUSSEL AVOCAT LITIGE TRANSPORTS MERCIER", -1800, "Frais juridiques"),
        ("2026-10-21", "VIR SEPA EMIS CABINET EXPERTISE AUTO SUD", -560, "Frais juridiques"),
        ("2026-10-26", "CARTE FORMATION DDA 15 HEURES", -390, "Formation"),
    ],
    "graine": 7,
    "convert": {"autres": [
        {"fichier": "bordereau-sinistres.csv", "titre": "Bordereau de sinistres (CSV)",
         "description": "Sinistres déclarés d'août à octobre : client, branche, nature, montant estimé, statut.",
         "colonnes": ["Date", "Client", "Branche", "Nature", "Montant estimé", "Statut"], "lignes": SINISTRES},
    ]},
    "tab": {
        "espace": "Arpège Courtage",
        "projet": "Portefeuille 2026",
        "tables": [
            {"nom": "Contrats",
             "colonnes": [col("Client", mapping="entity_title"), col("Branche", "select", choices=sorted({c[1] for c in CONTRATS})),
                          col("Assureur"), col("Prime annuelle", "currency", mapping="financial_ht"),
                          col("Sinistres 2026", "currency"),
                          col("S/P", "formula", formula="=E1/D1", format="percent"),
                          col("Échéance", "date", mapping="due_date"),
                          col("Renouvellement", "select", choices=["À faire", "En cours", "En revue", "Terminée"], mapping="workflow_state")],
             "lignes": [{"Client": c, "Branche": b, "Assureur": a, "Prime annuelle": p, "Sinistres 2026": s,
                         "Échéance": e, "Renouvellement": st} for c, b, a, p, e, s, st in CONTRATS]},
        ],
    },
    "viz": {"alerte": {"nom": "Frais juridiques du mois", "categorie": "Frais juridiques", "seuil": 800},
            "jeux_extra": [{"nom": "Sinistres", "source": "convert:bordereau-sinistres.csv"}]},
    "tresorerie": {"compte": "Compte pro Arpège Courtage", "type": "courant",
                   "budgets": {"Frais juridiques": 800, "Prospection": 400, "Formation": 400, "Logiciels": 450}},
    "projets": {
        "projet": "Renouvellements T4 2026 — Arpège Courtage",
        "description": "Préparer les échéances de fin d'année : une tâche par contrat à renouveler.",
        "phases": [
            {"titre": "Renouvellements", "epics": [{"titre": "Échéances novembre-décembre", "stories": [
                {"titre": "Contrats à renouveler", "items": [
                    {"titre": f"{c} — {b}", "statut": st, "echeance": e, "priorite": "HIGH" if s > p * 0.6 else "NORMAL"}
                    for c, b, a, p, e, s, st in CONTRATS if e <= "2026-12-31"]},
                {"titre": "Suivi des budgets", "alertes": True, "items": [
                    {"titre": "Litige Transports Mercier : point avec l'avocat", "statut": "En cours", "echeance": "2026-11-15"},
                ]},
            ]}]},
        ],
        "jalons": [{"titre": "Propositions de renouvellement envoyées", "date": "2026-11-30", "atteint": False}],
    },
    "wiki": {
        "espace": "Arpège Courtage", "icone": "🛡️",
        "description": "Procédures du cabinet et fiches par branche.",
        "pages": [
            {"titre": "Procédure de déclaration de sinistre", "icone": "🚨", "contenu": """1. Recueillir la déclaration du client sous 5 jours ouvrés (2 jours pour un vol).
2. Transmettre à l'assureur avec photos, constat et devis.
3. Noter le sinistre dans le bordereau mensuel (export *Bordereau de sinistres*, à convertir dans Convert).
4. Mettre à jour la colonne *Sinistres 2026* du contrat dans Tab : le ratio S/P se recalcule.
5. Au-delà de 60 % de S/P, préparer le renouvellement avec l'assureur (voir [[Fiche branche — flotte automobile]]).
"""},
            {"titre": "Fiche branche — flotte automobile", "icone": "🚚", "contenu": """Deux clients : Transports Mercier, Taxis Rive Droite.

Sinistralité 2026 élevée (S/P au-dessus de 75 % pour les deux). Pistes pour le renouvellement :
- franchise plus haute sur les dommages ;
- boîtiers de conduite et formation des chauffeurs ;
- mise en concurrence avec la Compagnie Horizon.
"""},
        ],
    },
    "nexus": {"workflows": ["convert-derniere-conversion-tab-viz", "viz-alerte-tache-projets"]},
}
