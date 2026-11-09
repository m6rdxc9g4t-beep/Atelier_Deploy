"""Marketing — une agence pilote la campagne de lancement d'une marque de cosmétiques."""

from .commun import col

# Performances quotidiennes par canal (export des régies), d'août à octobre.
PERF = []
for m, jours in (("2026-08", 31), ("2026-09", 30), ("2026-10", 31)):
    for j in range(1, jours + 1, 3):
        for canal, base_dep, cpc, tx in (("Meta", 38, 0.42, 0.031), ("Google Ads", 29, 0.61, 0.044), ("TikTok", 21, 0.28, 0.018)):
            boost = 2.6 if m == "2026-10" and j >= 4 and canal != "Google Ads" else (1.6 if m == "2026-10" else 1.0)
            dep = round(base_dep * boost * (1 + ((j * 7) % 11 - 5) / 40), 2)
            clics = int(dep / cpc)
            conv = max(0, int(clics * tx * (0.75 if canal == "Meta" and m == "2026-10" else 1)))
            PERF.append([f"{j:02d}/{m[5:]}/{m[:4]}", canal, f"{dep:.2f}".replace(".", ","), str(clics), str(conv)])

HISTOIRE = {
    "id": "marketing-campagne",
    "titre": "Campagne Brume",
    "sous_titre": "Lancement d'une marque de cosmétiques par une agence",
    "secteur": "Marketing",
    "resume": "L'agence Orbe lance la gamme d'automne de Brume Cosmétiques : plan média, performances par canal, "
              "factures des régies ; le budget Meta explose au lancement et le coût d'acquisition grimpe.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Lille Grand-Place — 18 rue Esquermoise, 59000 Lille",
               "titulaire": "AGENCE ORBE SARL", "compte": "Compte client Brume n° 00066554433"},
    "solde_initial": 9800.00,
    "recurrentes": [
        (6, "PRLV SEPA CANVA HUBSPOT SEMRUSH", -318, "Outils"),
        (28, "FRAIS TENUE DE COMPTE", -15, "Banque"),
    ],
    "ponctuelles": [
        ("2026-08-01", "VIR SEPA RECU BRUME COSMETIQUES BUDGET MEDIA AOUT", 4000, "Budget client"),
        ("2026-08-31", "PRLV SEPA META PLATFORMS IRELAND AOUT", -1250, "Meta"),
        ("2026-08-31", "PRLV SEPA GOOGLE IRELAND ADS AOUT", -940, "Google Ads"),
        ("2026-08-31", "PRLV SEPA TIKTOK ADS AOUT", -690, "TikTok"),
        ("2026-08-20", "VIR SEPA EMIS STUDIO LUMEN SHOOTING PRODUIT", -1600, "Production"),
        ("2026-09-01", "VIR SEPA RECU BRUME COSMETIQUES BUDGET MEDIA SEPTEMBRE", 4000, "Budget client"),
        ("2026-09-30", "PRLV SEPA META PLATFORMS IRELAND SEPTEMBRE", -1180, "Meta"),
        ("2026-09-30", "PRLV SEPA GOOGLE IRELAND ADS SEPTEMBRE", -910, "Google Ads"),
        ("2026-09-30", "PRLV SEPA TIKTOK ADS SEPTEMBRE", -660, "TikTok"),
        ("2026-09-14", "VIR SEPA EMIS COLLECTIF CREATEURS INFLUENCE", -1200, "Influence"),
        ("2026-10-01", "VIR SEPA RECU BRUME COSMETIQUES BUDGET MEDIA LANCEMENT", 9000, "Budget client"),
        ("2026-10-31", "PRLV SEPA META PLATFORMS IRELAND OCTOBRE", -4320, "Meta"),
        ("2026-10-31", "PRLV SEPA GOOGLE IRELAND ADS OCTOBRE", -1490, "Google Ads"),
        ("2026-10-31", "PRLV SEPA TIKTOK ADS OCTOBRE", -2210, "TikTok"),
        ("2026-10-08", "VIR SEPA EMIS COLLECTIF CREATEURS INFLUENCE LANCEMENT", -2500, "Influence"),
    ],
    "graine": 6,
    "convert": {"autres": [
        {"fichier": "performances-regies.csv", "titre": "Performances des régies (CSV)",
         "description": "Export Meta, Google Ads et TikTok : dépenses, clics et conversions tous les trois jours.",
         "colonnes": ["Date", "Canal", "Dépense", "Clics", "Conversions"], "lignes": PERF},
    ]},
    "tab": {
        "espace": "Agence Orbe",
        "projet": "Brume — lancement automne",
        "tables": [
            {"nom": "Plan média",
             "colonnes": [col("Action", mapping="entity_title"), col("Canal", "select", choices=["Meta", "Google Ads", "TikTok", "Influence"]),
                          col("Budget", "currency", mapping="financial_ht"), col("Début", "date", mapping="start_date"),
                          col("Fin", "date", mapping="due_date"), col("CPA cible", "currency"),
                          col("Statut", "select", choices=["À faire", "En cours", "Terminée"], mapping="workflow_state"),
                          col("Responsable", mapping="assignee")],
             "lignes": [
                 {"Action": "Teasing gamme automne", "Canal": "Meta", "Budget": 2400, "Début": "2026-08-15", "Fin": "2026-09-30", "CPA cible": 18, "Statut": "Terminée", "Responsable": "Clara Vasseur"},
                 {"Action": "Recherche marque et produits", "Canal": "Google Ads", "Budget": 3000, "Début": "2026-08-01", "Fin": "2026-12-31", "CPA cible": 15, "Statut": "En cours", "Responsable": "Théo Lambert"},
                 {"Action": "Lancement : vidéos courtes", "Canal": "TikTok", "Budget": 2200, "Début": "2026-10-01", "Fin": "2026-10-31", "CPA cible": 20, "Statut": "Terminée", "Responsable": "Clara Vasseur"},
                 {"Action": "Lancement : carrousels et stories", "Canal": "Meta", "Budget": 2500, "Début": "2026-10-01", "Fin": "2026-10-31", "CPA cible": 18, "Statut": "Terminée", "Responsable": "Clara Vasseur"},
                 {"Action": "Créateurs beauté (12 contenus)", "Canal": "Influence", "Budget": 3700, "Début": "2026-09-10", "Fin": "2026-10-20", "CPA cible": 25, "Statut": "Terminée", "Responsable": "Nora Belkacem"},
                 {"Action": "Retargeting fêtes de fin d'année", "Canal": "Meta", "Budget": 1800, "Début": "2026-11-15", "Fin": "2026-12-24", "CPA cible": 12, "Statut": "À faire", "Responsable": "Théo Lambert"},
             ]},
        ],
    },
    "viz": {"alerte": {"nom": "Dépenses Meta du mois", "categorie": "Meta", "seuil": 2500},
            "jeux_extra": [{"nom": "Performances des régies", "source": "convert:performances-regies.csv"}]},
    "tresorerie": {"compte": "Compte client Brume (agence Orbe)", "type": "courant",
                   "budgets": {"Meta": 2500, "Google Ads": 1500, "TikTok": 2200, "Influence": 2500, "Outils": 350}},
    "projets": {
        "projet": "Brume — lancement automne 2026",
        "description": "Campagne de lancement de la gamme d'automne de Brume Cosmétiques.",
        "phases": [
            {"titre": "Préparation", "epics": [{"titre": "Création", "stories": [
                {"titre": "Contenus", "items": [
                    {"titre": "Shooting produit (Studio Lumen)", "statut": "Terminée", "estime": 16, "passe": 18},
                    {"titre": "Déclinaisons des visuels par canal", "statut": "Terminée", "estime": 20, "passe": 24},
                    {"titre": "Brief des 12 créateurs", "statut": "Terminée", "estime": 6, "passe": 5},
                ]},
            ]}]},
            {"titre": "Diffusion", "epics": [{"titre": "Lancement d'octobre", "stories": [
                {"titre": "Pilotage des campagnes", "items": [
                    {"titre": "Suivi quotidien des performances", "statut": "Terminée", "estime": 20, "passe": 22},
                    {"titre": "Bilan du lancement pour Brume", "statut": "En cours", "estime": 8, "passe": 3, "echeance": "2026-11-10"},
                ]},
                {"titre": "Suivi des budgets", "alertes": True, "items": []},
            ]}]},
        ],
        "jalons": [{"titre": "Lancement de la gamme", "date": "2026-10-01", "atteint": True},
                   {"titre": "Bilan client", "date": "2026-11-10", "atteint": False}],
    },
    "wiki": {
        "espace": "Brume — campagne d'automne", "icone": "📣",
        "description": "Brief, règles de marque et bilan de la campagne de lancement.",
        "pages": [
            {"titre": "Brief de campagne", "icone": "🎯", "contenu": """**Client** : Brume Cosmétiques. **Produit** : gamme d'automne (sérum, crème, baume).

**Objectif** : 1 200 ventes en ligne en octobre, coût d'acquisition sous 20 €.

**Cibles** : 25-40 ans, sensibles aux cosmétiques naturels.

Plan média détaillé : table *Plan média* dans Tab. Règles de marque : [[Charte de marque Brume]].
"""},
            {"titre": "Charte de marque Brume", "icone": "🌫️", "contenu": """- Ton : calme, précis, jamais d'urgence artificielle (« dernière chance »…).
- Couleurs : gris brume, vert sauge, sable.
- Mentions obligatoires : liste INCI accessible depuis chaque publicité.
"""},
            {"titre": "Bilan intermédiaire du lancement", "icone": "📊", "contenu": """Octobre : Meta a dépensé bien au-delà de son budget (fréquence trop forte sur la même audience), pour un coût d'acquisition en hausse. TikTok tient son budget, Google reste le canal le plus rentable.

Suite : tâche de suivi dans Projets (story *Suivi des budgets*), performances par canal dans Viz.
"""},
        ],
    },
    "nexus": {"workflows": ["convert-derniere-conversion-tab-viz", "viz-alerte-tache-projets"]},
}
