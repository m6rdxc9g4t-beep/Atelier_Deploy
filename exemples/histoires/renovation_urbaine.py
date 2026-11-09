"""Rénovation Urbaine 2026 — suivi d'un chantier de réhabilitation (reprend l'exemple d'Atelier Tab)."""

from .commun import col

LOTS = [  # lot, statut, coût HT, responsable, échéance, avancement
    ("Gros œuvre", "En cours", 45000, "Marie Dubois", "2026-11-30", 0.7),
    ("Charpente bois", "Terminée", 28500, "Karim Benali", "2026-12-15", 1.0),
    ("Isolation thermique", "À faire", 15000, "Sophie Laurent", "2027-01-20", 0.0),
    ("Menuiseries extérieures", "En attente", 21400, "Karim Benali", "2027-01-31", 0.1),
    ("Électricité", "En cours", 18200, "Sophie Laurent", "2027-02-15", 0.35),
    ("Plomberie et chauffage", "À faire", 16800, "Marie Dubois", "2027-02-28", 0.0),
]

HISTOIRE = {
    "id": "renovation-urbaine",
    "titre": "Rénovation Urbaine 2026",
    "sous_titre": "Suivi d'un chantier de réhabilitation",
    "secteur": "Chantier",
    "resume": "La réhabilitation d'un immeuble de logements à Villeurbanne : planning des lots, situations de travaux "
              "payées depuis le compte chantier, budget par lot ; le gros œuvre dépasse son enveloppe du mois.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Villeurbanne Gratte-Ciel — 12 avenue Henri-Barbusse, 69100 Villeurbanne",
               "titulaire": "SCI RENOVATION URBAINE 2026", "compte": "Compte chantier n° 00045671230"},
    "solde_initial": 64200.00,
    "recurrentes": [
        (5, "PRLV SEPA ASSURANCE DOMMAGES-OUVRAGE", -612.50, "Assurances"),
        (10, "VIR SEPA EMIS ATELIER DUBOIS BENALI HONORAIRES {mois}", -1500, "Études et honoraires"),
        (28, "FRAIS TENUE DE COMPTE", -18, "Banque"),
    ],
    "ponctuelles": [
        ("2026-08-03", "VIR SEPA RECU METROPOLE DE LYON APPEL DE FONDS 3", 60000, "Appels de fonds"),
        ("2026-08-14", "VIR SEPA EMIS BTP RHONE SITUATION 4 GROS OEUVRE", -9800, "Gros œuvre"),
        ("2026-08-21", "VIR SEPA EMIS CHARPENTES DU BEAUJOLAIS SITUATION 2", -14250, "Charpente bois"),
        ("2026-08-26", "CARTE LOCATION ENGINS KILOUTOU", -1240, "Installation de chantier"),
        ("2026-09-02", "VIR SEPA RECU METROPOLE DE LYON APPEL DE FONDS 4", 45000, "Appels de fonds"),
        ("2026-09-12", "VIR SEPA EMIS BTP RHONE SITUATION 5 GROS OEUVRE", -11200, "Gros œuvre"),
        ("2026-09-18", "VIR SEPA EMIS CHARPENTES DU BEAUJOLAIS SITUATION 3 SOLDE", -14250, "Charpente bois"),
        ("2026-09-24", "VIR SEPA EMIS ELEC LUMIERE SITUATION 1", -4100, "Électricité"),
        ("2026-09-29", "CARTE BENNES ET DECHETS DU RHONE", -890, "Installation de chantier"),
        ("2026-10-01", "VIR SEPA RECU METROPOLE DE LYON APPEL DE FONDS 5", 45000, "Appels de fonds"),
        ("2026-10-09", "VIR SEPA EMIS BTP RHONE SITUATION 6 GROS OEUVRE", -12600, "Gros œuvre"),
        ("2026-10-15", "VIR SEPA EMIS ELEC LUMIERE SITUATION 2", -2270, "Électricité"),
        ("2026-10-20", "VIR SEPA EMIS BTP RHONE TRAVAUX SUPPLEMENTAIRES FONDATIONS", -3400, "Gros œuvre"),
        ("2026-10-23", "VIR SEPA EMIS MENUISERIES DU VAL ACOMPTE 30 %", -6420, "Menuiseries extérieures"),
        ("2026-10-27", "CARTE LOCATION ENGINS KILOUTOU", -980, "Installation de chantier"),
    ],
    "graine": 2,
    "convert": {"autres": [
        {"fichier": "situations-de-travaux.csv", "titre": "Situations de travaux (CSV)",
         "description": "Export du maître d'œuvre : une ligne par situation, lot et entreprise.",
         "colonnes": ["Date", "Lot", "Entreprise", "Situation", "Montant HT", "TVA", "Montant TTC"],
         "lignes": [
             ["14/08/2026", "Gros œuvre", "BTP Rhône", "4", "8166,67", "20 %", "9800,00"],
             ["21/08/2026", "Charpente bois", "Charpentes du Beaujolais", "2", "11875,00", "20 %", "14250,00"],
             ["12/09/2026", "Gros œuvre", "BTP Rhône", "5", "9333,33", "20 %", "11200,00"],
             ["18/09/2026", "Charpente bois", "Charpentes du Beaujolais", "3 (solde)", "11875,00", "20 %", "14250,00"],
             ["24/09/2026", "Électricité", "Élec Lumière", "1", "3416,67", "20 %", "4100,00"],
             ["09/10/2026", "Gros œuvre", "BTP Rhône", "6", "10500,00", "20 %", "12600,00"],
             ["15/10/2026", "Électricité", "Élec Lumière", "2", "1891,67", "20 %", "2270,00"],
             ["20/10/2026", "Gros œuvre", "BTP Rhône", "TS fondations", "2833,33", "20 %", "3400,00"],
             ["23/10/2026", "Menuiseries extérieures", "Menuiseries du Val", "Acompte", "5350,00", "20 %", "6420,00"],
         ]},
    ]},
    "tab": {
        "espace": "Rénovation Urbaine",
        "projet": "Rénovation Urbaine 2026",
        "tables": [
            {"nom": "Planning & Lots",
             "colonnes": [col("Lot / Tâche", mapping="entity_title"),
                          col("Statut", "select", choices=["À faire", "En cours", "En attente", "Terminée"], mapping="workflow_state"),
                          col("Coût HT", "currency", mapping="financial_ht"),
                          col("Coût TTC", "formula", formula="=C1*1.2", format="currency"),
                          col("Responsable", mapping="assignee"), col("Échéance", "date", mapping="due_date"),
                          col("Avancement", "percent")],
             "lignes": [{"Lot / Tâche": l, "Statut": s, "Coût HT": c, "Responsable": r, "Échéance": e, "Avancement": a}
                        for l, s, c, r, e, a in LOTS]},
        ],
    },
    "viz": {"alerte": {"nom": "Gros œuvre du mois", "categorie": "Gros œuvre", "seuil": 14000}},
    "tresorerie": {"compte": "Compte chantier Rénovation Urbaine 2026", "type": "courant",
                   "budgets": {"Gros œuvre": 14000, "Électricité": 4500, "Menuiseries extérieures": 7000,
                               "Installation de chantier": 1500, "Études et honoraires": 1500}},
    "projets": {
        "projet": "Rénovation Urbaine 2026",
        "description": "Réhabilitation d'un immeuble de 18 logements, rue Francis-de-Pressensé à Villeurbanne.",
        "phases": [
            {"titre": "Travaux", "epics": [
                {"titre": "Clos et couvert", "stories": [
                    {"titre": "Lots structure", "items": [
                        {"titre": l, "statut": s, "echeance": e, "estime": round(c / 600), "passe": round(c / 600 * a)}
                        for l, s, c, r, e, a in LOTS[:4]]},
                ]},
                {"titre": "Second œuvre", "stories": [
                    {"titre": "Lots techniques", "items": [
                        {"titre": l, "statut": s, "echeance": e, "estime": round(c / 600), "passe": round(c / 600 * a)}
                        for l, s, c, r, e, a in LOTS[4:]]},
                ]},
            ]},
            {"titre": "Pilotage", "epics": [{"titre": "Budget", "stories": [
                {"titre": "Suivi des budgets", "alertes": True, "items": [
                    {"titre": "Valider l'avenant travaux supplémentaires fondations", "statut": "En revue", "echeance": "2026-11-12"},
                ]},
            ]}]},
        ],
        "jalons": [{"titre": "Hors d'eau", "date": "2026-10-30", "atteint": True},
                   {"titre": "Hors d'air", "date": "2027-01-31", "atteint": False}],
    },
    "wiki": {
        "espace": "Rénovation Urbaine 2026", "icone": "🏗️",
        "description": "Comptes rendus de chantier, lots et procédures de réception.",
        "pages": [
            {"titre": "Compte rendu de chantier n° 14", "icone": "📝", "contenu": """Réunion du 22 octobre 2026, sur site.

**Présents** : Marie Dubois (maîtrise d'œuvre), Karim Benali, Sophie Laurent, BTP Rhône, Élec Lumière.

## Avancement
- Gros œuvre : 70 %. Fondations de la cage B reprises (travaux supplémentaires, 3 400 € TTC, avenant à signer).
- Charpente : terminée, réception partielle prononcée.
- Électricité : passage des gaines au R+1 et R+2.

## Décisions
- [ ] Avenant fondations à valider avant le 12 novembre.
- [ ] Menuiseries du Val : livraison des fenêtres le 18 novembre.

Voir la [[Liste des lots]].
"""},
            {"titre": "Liste des lots", "icone": "🧱", "contenu": """| Lot | Entreprise | Montant HT |
|---|---|---:|
| Gros œuvre | BTP Rhône | 45 000 € |
| Charpente bois | Charpentes du Beaujolais | 28 500 € |
| Isolation thermique | à attribuer | 15 000 € |
| Menuiseries extérieures | Menuiseries du Val | 21 400 € |
| Électricité | Élec Lumière | 18 200 € |
| Plomberie et chauffage | à attribuer | 16 800 € |

Réception d'un lot : voir [[Procédure de réception]].
"""},
            {"titre": "Procédure de réception", "icone": "✅", "contenu": """1. Visite contradictoire avec l'entreprise et la maîtrise d'œuvre.
2. Procès-verbal : réserves listées, délai de levée (30 jours en général).
3. Retenue de garantie de 5 % jusqu'à la levée des réserves.
4. Mettre à jour le statut du lot dans Tab (*Planning & Lots*), puis dans Projets.
"""},
        ],
    },
    "nexus": {"workflows": ["tab-planning-vers-projets", "viz-alerte-tache-projets"]},
}
