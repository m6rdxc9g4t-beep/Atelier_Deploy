#!/usr/bin/env bash
# auto-update.sh : chaque app suivie est reconstruite quand son dépôt change, et l'état affiché dit vrai.
source "$(dirname "$0")/banc.sh"

titre "Deux apps suivies publiées en même temps : les deux sont reconstruites"
banc_neuf
attendu "installation simulée (update.sh)" ./update.sh
publier agent-ops-lab; publier Atelier_Portefolio
vider_journal
attendu "auto-update.sh réussit" ./auto-update.sh
dans_journal "build ops"
dans_journal "build portfolio"
vider_journal
attendu "passage suivant" ./auto-update.sh
hors_journal "build" "plus rien à construire au passage suivant"
etat="$(./auto-update.sh status 2>&1)"
attendu "status : ops à jour" grep -q "ops : à jour" <<<"$etat"
attendu "status : portfolio à jour" grep -q "portfolio : à jour" <<<"$etat"

titre "Une construction en échec n'est pas annoncée « à jour »"
publier agent-ops-lab
DOCKER_FAIL_ON="build ops" attendu "auto-update.sh se termine" ./auto-update.sh
etat="$(./auto-update.sh status 2>&1)"
attendu "status : ops en échec" grep -q "ops : ÉCHEC" <<<"$etat"
refuse "status : ops n'est pas dit à jour" grep -q "ops : à jour" <<<"$etat"
attendu "sudo ./update.sh ops réussit ensuite" ./update.sh ops
attendu "status : ops de nouveau à jour" grep -q "ops : à jour" <<<"$(./auto-update.sh status 2>&1)"

banc_fin
