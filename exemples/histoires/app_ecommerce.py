"""App E-Commerce v2 — une boutique de thés en ligne lance la v2 de son application."""

import random

from .commun import col

# Commandes de la boutique (export du back-office), reproductibles.
_rnd = random.Random(31)
_PRODUITS = [("Thé vert Sencha", 14.5), ("Rooibos vanille", 11.9), ("Earl Grey fleurs bleues", 13.2),
             ("Coffret découverte", 39.0), ("Théière fonte 0,8 L", 54.0), ("Matcha cérémonie", 29.5)]
COMMANDES = []
for m, n, panier in (("2026-08", 118, 1.0), ("2026-09", 131, 0.95), ("2026-10", 164, 0.82)):
    for i in range(n):
        jour = _rnd.randint(1, 31 if m != "2026-09" else 30)
        nb = _rnd.choice([1, 1, 1, 2, 2, 3])
        lignes = [_rnd.choice(_PRODUITS) for _ in range(nb)]
        montant = round(sum(p for _, p in lignes) * panier, 2)
        COMMANDES.append({"date": f"{m}-{jour:02d}", "numero": f"VV-{m[5:]}{i + 1:04d}", "produit": lignes[0][0],
                          "articles": nb, "montant": montant,
                          "canal": _rnd.choice(["App v1", "App v1", "Site web"] if m != "2026-10" else ["App v2", "App v2", "Site web"])})
COMMANDES.sort(key=lambda c: (c["date"], c["numero"]))


def _ventes(m: str) -> float:
    return round(sum(c["montant"] for c in COMMANDES if c["date"].startswith(m)), 2)


HISTOIRE = {
    "id": "app-ecommerce",
    "titre": "App E-Commerce v2",
    "sous_titre": "Une boutique en ligne lance la v2 de son app",
    "secteur": "Produit",
    "resume": "Verveine & Co, boutique de thés en ligne, sort la v2 de son app en octobre : backlog et sprints, "
              "commandes du back-office, virements Stripe ; la pub du lancement dépasse son budget.",
    "banque": {"nom": "BANQUE EXEMPLE", "agence": "Agence Nantes Graslin — 2 rue Racine, 44000 Nantes",
               "titulaire": "VERVEINE & CO SAS", "compte": "Compte professionnel n° 00077123456"},
    "solde_initial": 38450.00,
    "recurrentes": [
        (2, "PRLV SEPA SCALINGO HEBERGEMENT", -389, "Hébergement"),
        (5, "VIR SEPA EMIS SALAIRES {mois}", -9800, "Salaires"),
        (8, "PRLV SEPA COLISSIMO EXPEDITIONS", -640, "Logistique", 0.15),
        (15, "PRLV SEPA FIGMA GITHUB SENTRY", -212, "Outils"),
        (28, "FRAIS TENUE DE COMPTE", -24, "Banque"),
    ],
    "ponctuelles": [
        ("2026-08-07", "VIR SEPA RECU STRIPE PAYOUTS", round(_ventes("2026-08") * 0.48, 2), "Ventes"),
        ("2026-08-21", "VIR SEPA RECU STRIPE PAYOUTS", round(_ventes("2026-08") * 0.50, 2), "Ventes"),
        ("2026-08-12", "VIR SEPA EMIS JARDINS DE NILGIRI ACHAT THES", -2850, "Achats marchandises"),
        ("2026-08-19", "CARTE META ADS", -420, "Publicité"),
        ("2026-09-04", "VIR SEPA RECU STRIPE PAYOUTS", round(_ventes("2026-09") * 0.47, 2), "Ventes"),
        ("2026-09-18", "VIR SEPA RECU STRIPE PAYOUTS", round(_ventes("2026-09") * 0.51, 2), "Ventes"),
        ("2026-09-10", "VIR SEPA EMIS JARDINS DE NILGIRI ACHAT THES", -3120, "Achats marchandises"),
        ("2026-09-23", "CARTE META ADS", -510, "Publicité"),
        ("2026-09-30", "VIR SEPA EMIS STUDIO PIXEL FREELANCE DESIGN V2", -2400, "Prestataires"),
        ("2026-10-02", "VIR SEPA RECU STRIPE PAYOUTS", round(_ventes("2026-10") * 0.46, 2), "Ventes"),
        ("2026-10-16", "VIR SEPA RECU STRIPE PAYOUTS", round(_ventes("2026-10") * 0.52, 2), "Ventes"),
        ("2026-10-06", "CARTE META ADS LANCEMENT V2", -1180, "Publicité"),
        ("2026-10-08", "CARTE GOOGLE ADS LANCEMENT V2", -760, "Publicité"),
        ("2026-10-13", "VIR SEPA EMIS JARDINS DE NILGIRI ACHAT THES", -3990, "Achats marchandises"),
        ("2026-10-22", "CARTE META ADS", -540, "Publicité"),
    ],
    "graine": 3,
    "convert": {"autres": [
        {"fichier": "commandes-back-office.csv", "titre": "Commandes du back-office (CSV)",
         "description": "Export des commandes d'août à octobre : numéro, produit, montant, canal (app v1, v2, site).",
         "colonnes": ["Date", "Commande", "Premier produit", "Articles", "Montant TTC", "Canal"],
         "lignes": [[f"{c['date'][8:]}/{c['date'][5:7]}/{c['date'][:4]}", c["numero"], c["produit"], str(c["articles"]),
                     f"{c['montant']:.2f}".replace(".", ","), c["canal"]] for c in COMMANDES]},
    ]},
    "tab": {
        "espace": "Verveine & Co",
        "projet": "App E-Commerce v2",
        "tables": [
            {"nom": "Backlog v2",
             "colonnes": [col("Récit", mapping="entity_title"), col("Type", "select", choices=["Feature", "Bug", "Task"], mapping="item_type"),
                          col("Sprint", "select", choices=["Sprint 7", "Sprint 8", "Sprint 9"]),
                          col("Points", "number"),
                          col("Statut", "select", choices=["À faire", "En cours", "En revue", "Terminée"], mapping="workflow_state"),
                          col("Responsable", mapping="assignee"), col("Échéance", "date", mapping="due_date"),
                          col("Temps passé (h)", "number", mapping="time_spent")],
             "lignes": [
                 {"Récit": "Paiement en un clic (Apple Pay, Google Pay)", "Type": "Feature", "Sprint": "Sprint 7", "Points": 8, "Statut": "Terminée", "Responsable": "Inès Garnier", "Échéance": "2026-09-12", "Temps passé (h)": 26},
                 {"Récit": "Nouveau tunnel de commande en 3 étapes", "Type": "Feature", "Sprint": "Sprint 7", "Points": 13, "Statut": "Terminée", "Responsable": "Hugo Petit", "Échéance": "2026-09-12", "Temps passé (h)": 41},
                 {"Récit": "Fiches produit : notes de dégustation", "Type": "Feature", "Sprint": "Sprint 8", "Points": 5, "Statut": "Terminée", "Responsable": "Inès Garnier", "Échéance": "2026-09-26", "Temps passé (h)": 14},
                 {"Récit": "Abonnement mensuel « Thé du mois »", "Type": "Feature", "Sprint": "Sprint 8", "Points": 13, "Statut": "En revue", "Responsable": "Hugo Petit", "Échéance": "2026-10-10", "Temps passé (h)": 38},
                 {"Récit": "Panier perdu après mise en veille (iOS)", "Type": "Bug", "Sprint": "Sprint 8", "Points": 3, "Statut": "Terminée", "Responsable": "Lina Haddad", "Échéance": "2026-09-30", "Temps passé (h)": 7},
                 {"Récit": "Mise en production v2 (stores)", "Type": "Task", "Sprint": "Sprint 9", "Points": 5, "Statut": "Terminée", "Responsable": "Lina Haddad", "Échéance": "2026-10-05", "Temps passé (h)": 12},
                 {"Récit": "Relances paniers abandonnés par notification", "Type": "Feature", "Sprint": "Sprint 9", "Points": 8, "Statut": "En cours", "Responsable": "Inès Garnier", "Échéance": "2026-10-24", "Temps passé (h)": 15},
                 {"Récit": "Panier moyen en baisse depuis la v2 : analyser", "Type": "Task", "Sprint": "Sprint 9", "Points": 3, "Statut": "À faire", "Responsable": "Hugo Petit", "Échéance": "2026-10-31", "Temps passé (h)": 0},
             ]},
        ],
    },
    "viz": {"alerte": {"nom": "Publicité du mois", "categorie": "Publicité", "seuil": 1500},
            "jeux_extra": [{"nom": "Commandes", "source": "convert:commandes-back-office.csv"}]},
    "tresorerie": {"compte": "Compte pro Verveine & Co", "type": "courant",
                   "budgets": {"Publicité": 1500, "Achats marchandises": 4500, "Hébergement": 450, "Logistique": 900,
                               "Outils": 250}},
    "projets": {
        "projet": "App E-Commerce v2 — Verveine & Co",
        "description": "Refonte de l'application mobile et du tunnel de commande, sortie en octobre 2026.",
        "phases": [
            {"titre": "Développement v2", "epics": [
                {"titre": "Tunnel de commande", "stories": [
                    {"titre": "Paiement et panier", "items": [
                        {"titre": "Paiement en un clic (Apple Pay, Google Pay)", "type": "FEATURE", "statut": "Terminée", "estime": 24, "passe": 26},
                        {"titre": "Nouveau tunnel de commande en 3 étapes", "type": "FEATURE", "statut": "Terminée", "estime": 36, "passe": 41},
                        {"titre": "Panier perdu après mise en veille (iOS)", "type": "BUG", "statut": "Terminée", "estime": 6, "passe": 7},
                    ]},
                ]},
                {"titre": "Fidélisation", "stories": [
                    {"titre": "Abonnements et relances", "items": [
                        {"titre": "Abonnement mensuel « Thé du mois »", "type": "FEATURE", "statut": "En revue", "estime": 32, "passe": 38},
                        {"titre": "Relances paniers abandonnés par notification", "type": "FEATURE", "statut": "En cours", "estime": 20, "passe": 15, "echeance": "2026-10-24"},
                    ]},
                ]},
            ]},
            {"titre": "Lancement", "epics": [{"titre": "Mise sur le marché", "stories": [
                {"titre": "Suivi des budgets", "alertes": True, "items": [
                    {"titre": "Panier moyen en baisse depuis la v2 : analyser", "statut": "À faire", "echeance": "2026-10-31", "priorite": "HIGH"},
                ]},
            ]}]},
        ],
        "jalons": [{"titre": "v2 en production sur les stores", "date": "2026-10-05", "atteint": True},
                   {"titre": "Bilan du lancement", "date": "2026-11-30", "atteint": False}],
    },
    "wiki": {
        "espace": "Verveine & Co — App v2", "icone": "🍵",
        "description": "Spécifications, rétrospectives et bilan du lancement de l'app v2.",
        "pages": [
            {"titre": "Spécification du tunnel de commande", "icone": "🛒", "contenu": """Trois étapes : panier, livraison, paiement.

- Paiement en un clic (Apple Pay, Google Pay) dès qu'un moyen est enregistré.
- Le panier est sauvegardé côté serveur : il survit à la mise en veille (bug iOS du sprint 8).
- Abandon de panier : notification à H+2, puis e-mail à J+1.

Suivi : backlog *Backlog v2* dans Tab, projet *App E-Commerce v2* dans Projets.
"""},
            {"titre": "Rétrospective du sprint 9", "icone": "🔁", "contenu": """## Ce qui a marché
- Sortie de la v2 le 5 octobre sans incident majeur.

## À améliorer
- Le panier moyen baisse depuis la v2 (voir le jeu *Commandes* dans Viz) : l'affichage du coffret découverte a disparu de la page d'accueil.
- La publicité du lancement a dépassé son budget : voir [[Bilan du lancement]].
"""},
            {"titre": "Bilan du lancement", "icone": "🚀", "contenu": """Commandes d'octobre en hausse, panier moyen en baisse. Dépenses publicitaires : Meta et Google au-dessus de l'enveloppe prévue.

Prochaines actions dans Projets, story *Suivi des budgets*.
"""},
        ],
    },
    "nexus": {"workflows": ["projets-temps-hebdo-viz", "viz-alerte-tache-projets"]},
}
