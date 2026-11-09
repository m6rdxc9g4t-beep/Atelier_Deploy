"""Immobilier — une SCI familiale gère six appartements en location à Nantes."""

from .commun import col

LOTS = [  # lot, locataire, loyer, charges, fin de bail, payé en octobre
    ("Apt 1 — T2 rez-de-chaussée", "Claire Fontaine", 640, 60, "2028-06-30", True),
    ("Apt 2 — T3 1er étage", "Mehdi Saïdi", 820, 75, "2027-09-30", True),
    ("Apt 3 — T2 1er étage", "Anaïs Roux", 655, 60, "2029-01-31", True),
    ("Apt 4 — T4 2e étage", "Famille Nguyen", 980, 90, "2027-03-31", False),
    ("Apt 5 — Studio 3e étage", "Lucas Ferrand", 470, 40, "2026-12-31", True),
    ("Apt 6 — T3 3e étage", "(vacant depuis le 15/09)", 810, 75, "", False),
]

_loyers = []
for m, vacant6 in (("2026-08", False), ("2026-09", False), ("2026-10", True)):
    for i, (lot, loc, loyer, ch, fin, paye_oct) in enumerate(LOTS):
        if i == 5 and vacant6:
            continue
        if i == 5 and m == "2026-09":
            loyer, ch = round((loyer + ch) * 14 / 30, 2), 0  # départ au 15 septembre, prorata
        if m == "2026-10" and not paye_oct:
            continue
        payeur = "PAUL BESSON" if i == 5 else loc.upper().replace("FAMILLE ", "")  # locataire de l'apt 6 jusqu'au 15/09
        _loyers.append((f"{m}-{3 + i:02d}", f"VIR SEPA RECU {payeur} LOYER {lot.split(' —')[0].upper()}", loyer + ch, "Loyers"))

HISTOIRE = {
    "id": "immobilier-locatif",
    "titre": "SCI Les Tilleuls",
    "sous_titre": "Gestion locative de six appartements",
    "secteur": "Immobilier",
    "resume": "La SCI familiale Les Tilleuls loue six appartements à Nantes : loyers encaissés, charges, "
              "état locatif, travaux ; en octobre un appartement est vacant, un loyer est impayé et les "
              "travaux de remise en état dépassent leur budget.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Nantes Commerce — 5 place du Commerce, 44000 Nantes",
               "titulaire": "SCI LES TILLEULS", "compte": "Compte courant n° 00022113344"},
    "solde_initial": 11480.00,
    "recurrentes": [
        (10, "PRLV SEPA PRET IMMOBILIER ECHEANCE {mois}", -2380, "Emprunt"),
        (15, "PRLV SEPA ASSURANCE PNO MUTUELLE DU MIDI", -93.33, "Assurances"),
        (20, "PRLV SEPA SYNDIC NANTES CENTRE APPEL DE CHARGES", -410, "Charges de copropriété"),
        (28, "FRAIS TENUE DE COMPTE", -12, "Banque"),
    ],
    "ponctuelles": _loyers + [
        ("2026-08-22", "VIR SEPA EMIS PLOMBERIE ERDRE REPARATION CHAUFFE-EAU APT 2", -540, "Travaux"),
        ("2026-09-02", "VIR SEPA EMIS ARTISAN DEGAT DES EAUX APT 4", -1150, "Travaux"),
        ("2026-09-27", "VIR SEPA RECU MUTUELLE DU MIDI INDEMNITE SINISTRE", 980, "Indemnités d'assurance"),
        ("2026-10-06", "VIR SEPA EMIS PEINTURES DE LOIRE REMISE EN ETAT APT 6", -2650, "Travaux"),
        ("2026-10-13", "CARTE LEROY MERLIN NANTES SOLS APT 6", -890, "Travaux"),
        ("2026-10-15", "PRLV SEPA TAXE FONCIERE 2026", -3240, "Taxe foncière"),
        ("2026-10-21", "CARTE ANNONCE LOCATION SELOGER APT 6", -79, "Gestion locative"),
    ],
    "graine": 9,
    "convert": {"autres": [
        {"fichier": "quittances-octobre.csv", "titre": "Quittances d'octobre (CSV)",
         "description": "Appels de loyer du mois : lot, locataire, loyer, charges, montant payé.",
         "colonnes": ["Lot", "Locataire", "Loyer", "Charges", "Appelé", "Payé"],
         "lignes": [[lot, loc, f"{loyer},00", f"{ch},00", f"{loyer + ch},00", f"{loyer + ch if paye else 0},00"]
                    for lot, loc, loyer, ch, fin, paye in LOTS if fin]},
    ]},
    "tab": {
        "espace": "SCI Les Tilleuls",
        "projet": "Gestion locative",
        "tables": [
            {"nom": "État locatif",
             "colonnes": [col("Lot", mapping="entity_title"), col("Locataire"), col("Loyer", "currency"), col("Charges", "currency"),
                          col("Total mensuel", "formula", formula="=C1+D1", format="currency"),
                          col("Fin de bail", "date", mapping="due_date"),
                          col("Octobre payé", "checkbox"),
                          col("Situation", "select", choices=["À faire", "En cours", "Bloquée", "Terminée"], mapping="workflow_state")],
             "lignes": [{"Lot": lot, "Locataire": loc, "Loyer": loyer, "Charges": ch, "Fin de bail": fin or None,
                         "Octobre payé": paye, "Situation": "Terminée" if paye else ("En cours" if fin else "Bloquée")}
                        for lot, loc, loyer, ch, fin, paye in LOTS]},
        ],
    },
    "viz": {"alerte": {"nom": "Travaux du mois", "categorie": "Travaux", "seuil": 1500}},
    "tresorerie": {"compte": "Compte courant SCI Les Tilleuls", "type": "courant",
                   "budgets": {"Travaux": 1500, "Charges de copropriété": 450, "Gestion locative": 100,
                               "Assurances": 100}},
    "projets": {
        "projet": "Gestion 2026 — SCI Les Tilleuls",
        "description": "Relocation de l'appartement 6, impayés et travaux de l'année.",
        "phases": [
            {"titre": "Gestion courante", "epics": [{"titre": "Automne 2026", "stories": [
                {"titre": "Relocation de l'appartement 6", "items": [
                    {"titre": "Remise en état (peinture, sols)", "statut": "Terminée", "echeance": "2026-10-20"},
                    {"titre": "Publier l'annonce et organiser les visites", "statut": "En cours", "echeance": "2026-11-10"},
                    {"titre": "Constituer le dossier du futur locataire", "statut": "À faire", "echeance": "2026-11-25"},
                ]},
                {"titre": "Impayés", "items": [
                    {"titre": "Relance amiable famille Nguyen (loyer d'octobre)", "statut": "En cours", "echeance": "2026-11-08", "priorite": "HIGH"},
                ]},
                {"titre": "Suivi des budgets", "alertes": True, "items": []},
            ]}]},
        ],
        "jalons": [{"titre": "Appartement 6 reloué", "date": "2026-12-01", "atteint": False},
                   {"titre": "Assemblée générale de la SCI", "date": "2026-12-15", "atteint": False}],
    },
    "wiki": {
        "espace": "SCI Les Tilleuls", "icone": "🏠",
        "description": "Procédures de gestion locative et comptes rendus de la SCI.",
        "pages": [
            {"titre": "Entrée et sortie d'un locataire", "icone": "🔑", "contenu": """## Entrée
1. Bail signé, dépôt de garantie (un mois hors charges) encaissé.
2. État des lieux d'entrée avec photos.
3. Ajouter le locataire dans l'état locatif (Tab, table *État locatif*).

## Sortie
1. État des lieux de sortie, comparaison avec l'entrée.
2. Restitution du dépôt sous un mois (deux en cas de dégradations).
3. Remise en état : une tâche par lot dans Projets.
"""},
            {"titre": "Procédure en cas d'impayé", "icone": "⚠️", "contenu": """- J+5 : relance amiable (téléphone puis courrier).
- J+15 : mise en demeure en recommandé.
- J+30 : déclaration à l'assurance loyers impayés, s'il y en a une ; sinon commandement de payer par huissier.

Suivi dans Projets, story *Impayés*.
"""},
            {"titre": "Assemblée générale 2026 — ordre du jour", "icone": "🗳️", "contenu": """1. Comptes 2026 : loyers, travaux, taxe foncière.
2. Relocation de l'appartement 6.
3. Travaux 2027 : isolation des combles (devis à demander).

Voir [[Entrée et sortie d'un locataire]].
"""},
        ],
    },
    "nexus": {"workflows": ["convert-derniere-conversion-tab-viz", "viz-alerte-tache-projets"]},
}
