"""Studio Garance — clôture comptable mensuelle d'un studio de design graphique (Arles)."""

from .commun import col

O = [  # (date, libellé, montant, catégorie) ; montant < 0 = débit
    ("2026-08-01", "PRLV SEPA SCI DES TANNEURS LOYER ATELIER", -1150, "Locaux"),
    ("2026-08-04", "PRLV SEPA ADOBE CREATIVE CLOUD", -71.99, "Logiciels"),
    ("2026-08-06", "VIR SEPA RECU MAISON VAUCLAIR FACT 2026-031", 1800, "Ventes"),
    ("2026-08-08", "PRLV SEPA ORANGE PRO", -54.99, "Télécom"),
    ("2026-08-12", "CARTE BOESNER FOURNITURES ARLES", -186.30, "Matériel"),
    ("2026-08-16", "PRLV SEPA URSSAF", -640, "Charges sociales"),
    ("2026-08-18", "CARTE LDLC PRO DISQUE SSD", -389, "Matériel"),
    ("2026-08-20", "VIR SEPA RECU CAFE LISIERE FACT 2026-033", 1800, "Ventes"),
    ("2026-08-22", "CARTE SNCF CONNECT", -124, "Déplacements"),
    ("2026-08-25", "CARTE BRASSERIE DU FORUM", -58.40, "Repas"),
    ("2026-08-26", "PRLV SEPA IONOS HEBERGEMENT", -182.32, "Logiciels"),
    ("2026-08-27", "PRLV SEPA ASSURANCE RC PRO", -48.20, "Assurances"),
    ("2026-08-29", "FRAIS TENUE DE COMPTE", -9, "Banque"),
    ("2026-09-01", "PRLV SEPA SCI DES TANNEURS LOYER ATELIER", -1150, "Locaux"),
    ("2026-09-04", "PRLV SEPA ADOBE CREATIVE CLOUD", -71.99, "Logiciels"),
    ("2026-09-05", "VIR SEPA RECU LES HALLES D ARLES FACT 2026-034", 2350, "Ventes"),
    ("2026-09-09", "PRLV SEPA ORANGE PRO", -54.99, "Télécom"),
    ("2026-09-11", "CARTE BOESNER FOURNITURES ARLES", -212.80, "Matériel"),
    ("2026-09-15", "VIR SEPA EMIS ECOLE ESTIENNE FORMATION", -450, "Formation"),
    ("2026-09-16", "PRLV SEPA URSSAF", -640, "Charges sociales"),
    ("2026-09-17", "CARTE LDLC PRO ECRAN 27 POUCES", -304.22, "Matériel"),
    ("2026-09-19", "VIR SEPA RECU MAISON VAUCLAIR FACT 2026-036", 1800, "Ventes"),
    ("2026-09-22", "CARTE SNCF CONNECT", -156.40, "Déplacements"),
    ("2026-09-24", "CARTE IMPRIMERIE DU RHONE", -268, "Matériel"),
    ("2026-09-26", "PRLV SEPA ASSURANCE RC PRO", -48.20, "Assurances"),
    ("2026-09-29", "FRAIS TENUE DE COMPTE", -9, "Banque"),
    ("2026-09-30", "CARTE BRASSERIE DU FORUM", -36.50, "Repas"),
    ("2026-10-01", "PRLV SEPA SCI DES TANNEURS LOYER ATELIER", -1150, "Locaux"),
    ("2026-10-02", "VIR SEPA RECU MAISON VAUCLAIR FACT 2026-038", 2400, "Ventes"),
    ("2026-10-04", "PRLV SEPA ADOBE CREATIVE CLOUD", -71.99, "Logiciels"),
    ("2026-10-07", "CARTE BOESNER FOURNITURES ARLES", -238.40, "Matériel"),
    ("2026-10-09", "PRLV SEPA ORANGE PRO", -54.99, "Télécom"),
    ("2026-10-12", "VIR SEPA RECU LES HALLES D ARLES FACT 2026-039", 1850, "Ventes"),
    ("2026-10-14", "CARTE IMPRIMERIE DU RHONE", -312, "Matériel"),
    ("2026-10-16", "PRLV SEPA URSSAF", -640, "Charges sociales"),
    ("2026-10-19", "CARTE SNCF CONNECT", -89.50, "Déplacements"),
    ("2026-10-21", "CARTE BOESNER FOURNITURES ARLES", -157.60, "Matériel"),
    ("2026-10-23", "VIR SEPA RECU CAFE LISIERE FACT 2026-041", 960, "Ventes"),
    ("2026-10-27", "PRLV SEPA ASSURANCE RC PRO", -48.20, "Assurances"),
    ("2026-10-29", "FRAIS TENUE DE COMPTE", -9, "Banque"),
    ("2026-10-30", "CARTE BRASSERIE DU FORUM", -42.80, "Repas"),
]

HISTOIRE = {
    "id": "studio-garance",
    "titre": "Studio Garance",
    "sous_titre": "Clôture comptable d'un studio de design",
    "secteur": "Compta",
    "resume": "Un studio de design graphique d'Arles clôture son mois : relevés bancaires convertis, catégorisés, "
              "comparés au budget ; le poste Matériel dépasse et devient une tâche de suivi.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Arles République — 4 rue de la République, 13200 Arles",
               "titulaire": "STUDIO GARANCE — EI", "compte": "Compte professionnel n° 00098765432"},
    "solde_initial": 2776.65,
    "ponctuelles": O,
    "recurrentes": [],
    "graine": 1,
    "convert": {"autres": []},
    "tab": {
        "espace": "Studio Garance",
        "projet": "Compta 2026",
        "tables": [
            {"nom": "Clients et factures",
             "colonnes": [col("Facture", mapping="entity_title"), col("Client"), col("Émise le", "date"),
                          col("Montant HT", "currency", mapping="financial_ht"),
                          col("Statut", "select", choices=["À faire", "En cours", "Terminée"], mapping="workflow_state")],
             "lignes": [
                 {"Facture": "2026-031", "Client": "Maison Vauclair", "Émise le": "2026-07-28", "Montant HT": 1500, "Statut": "Terminée"},
                 {"Facture": "2026-033", "Client": "Café Lisière", "Émise le": "2026-08-05", "Montant HT": 1500, "Statut": "Terminée"},
                 {"Facture": "2026-034", "Client": "Les Halles d'Arles", "Émise le": "2026-08-25", "Montant HT": 1958.33, "Statut": "Terminée"},
                 {"Facture": "2026-036", "Client": "Maison Vauclair", "Émise le": "2026-09-08", "Montant HT": 1500, "Statut": "Terminée"},
                 {"Facture": "2026-038", "Client": "Maison Vauclair", "Émise le": "2026-09-25", "Montant HT": 2000, "Statut": "Terminée"},
                 {"Facture": "2026-039", "Client": "Les Halles d'Arles", "Émise le": "2026-10-01", "Montant HT": 1541.67, "Statut": "Terminée"},
                 {"Facture": "2026-041", "Client": "Café Lisière", "Émise le": "2026-10-10", "Montant HT": 800, "Statut": "Terminée"},
                 {"Facture": "2026-043", "Client": "Domaine des Alpilles", "Émise le": "2026-10-28", "Montant HT": 2650, "Statut": "En cours"},
             ]},
        ],
    },
    "viz": {"alerte": {"nom": "Matériel du mois", "categorie": "Matériel", "seuil": 600}},
    "tresorerie": {"compte": "Compte pro Studio Garance", "type": "courant",
                   "budgets": {"Locaux": 1500, "Matériel": 600, "Logiciels": 80, "Déplacements": 150, "Repas": 100,
                               "Télécom": 80}},
    "projets": {
        "projet": "Gestion 2026 — Studio Garance",
        "description": "Clôtures mensuelles et suivi des budgets du studio.",
        "phases": [{"titre": "Clôtures mensuelles", "epics": [{"titre": "Octobre 2026", "stories": [
            {"titre": "Clôture d'octobre", "items": [
                {"titre": "Rapprocher le relevé d'octobre", "statut": "Terminée", "passe": 0.75, "echeance": "2026-11-05"},
                {"titre": "Catégoriser les opérations d'octobre dans Tab", "statut": "Terminée", "passe": 0.5, "echeance": "2026-11-05"},
                {"titre": "Relancer la facture 2026-043 (Domaine des Alpilles)", "statut": "À faire", "echeance": "2026-11-20"},
            ]},
            {"titre": "Suivi des budgets", "alertes": True, "items": []},
        ]}]}],
        "jalons": [{"titre": "Clôture d'octobre", "date": "2026-11-06", "atteint": True}],
    },
    "wiki": {
        "espace": "Studio Garance", "icone": "🎨",
        "description": "Procédures et clôtures mensuelles du studio.",
        "pages": [
            {"titre": "Fournisseurs", "icone": "🏷️", "contenu": """Fournisseurs réguliers du studio.

| Fournisseur | Poste | Remarque |
|---|---|---|
| Boesner (Arles) | Matériel | Papiers, encres, cadres. Deux à trois passages par mois. |
| Imprimerie du Rhône | Matériel | Tirages clients : à refacturer quand c'est possible. |
| LDLC Pro | Matériel | Informatique. |
| Adobe, Ionos | Logiciels | Abonnements mensuels. |
| SCI des Tanneurs | Locaux | Loyer de l'atelier, le 1er du mois. |
"""},
        ],
    },
    "nexus": {"workflows": ["convert-derniere-conversion-tab-viz", "viz-alerte-tache-projets"]},
}
