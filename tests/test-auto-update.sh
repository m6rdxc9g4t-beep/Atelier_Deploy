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

titre "Panne passagère : le même commit est retenté au passage suivant"
banc_neuf
attendu "installation simulée (update.sh)" ./update.sh
publier agent-ops-lab
vider_journal
DOCKER_FAIL_ONCE="build ops" attendu "premier passage (construction en panne)" ./auto-update.sh
attendu "l'échec est noté avec son numéro d'essai" grep -q " 1$" logs/echec-ops
attendu "second passage" ./auto-update.sh
attendu "ops a été construit deux fois" test "$(compte_journal 'build ops')" = 2
refuse "l'échec est effacé" test -e logs/echec-ops
attendu "status : ops à jour" grep -q "ops : à jour" <<<"$(./auto-update.sh status 2>&1)"

titre "Panne durable : trois essais, puis on attend le commit suivant"
publier agent-ops-lab
vider_journal
for _ in 1 2 3 4 5; do DOCKER_FAIL_ON="build ops" ./auto-update.sh >/dev/null 2>&1; done
attendu "trois essais, pas un de plus" test "$(compte_journal 'build ops')" = 3
attendu "status : ops en échec" grep -q "ops : ÉCHEC" <<<"$(./auto-update.sh status 2>&1)"
publier agent-ops-lab
attendu "un nouveau commit relance la mise à jour" ./auto-update.sh
attendu "ops est reconstruit" test "$(compte_journal 'build ops')" = 4
refuse "l'échec est effacé" test -e logs/echec-ops

titre "Le journal ne grossit pas sans fin"
mkdir -p logs
head -c 6000000 /dev/zero | tr '\0' 'x' > logs/auto-update.log
attendu "auto-update.sh réussit" ./auto-update.sh
attendu "au-delà de 5 Mo, le journal repart de zéro" test "$(stat -c %s logs/auto-update.log)" -lt 100000
attendu "l'ancien contenu est gardé une fois" test "$(stat -c %s logs/auto-update.log.1)" -ge 6000000
echo "ligne récente" > logs/auto-update.log
attendu "auto-update.sh réussit" ./auto-update.sh
attendu "un petit journal n'est pas touché" grep -q "ligne récente" logs/auto-update.log

banc_fin
