#!/bin/bash
# ============================================================================
# ORCHESTRATION J07 : EXECUTION HIVE SEQUENTIELLE ET EXPORTS D AUDIT
# ============================================================================
set -euo pipefail

RUN_ID="RUN_J07_$(date +%Y%m%d_%H%M%S)"
HIVE_URL="jdbc:hive2://localhost:10000"
LOG_FILE="05_rapports/j7_execution_hive.log"

rm -rf /tmp/j7_raw
mkdir -p /tmp/j7_raw
mkdir -p 05_rapports
: > "$LOG_FILE"

run_hive_script() {
    local script_path="$1"
    echo "==================================================================" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Execution de : $script_path (run_id=$RUN_ID)" | tee -a "$LOG_FILE"
    echo "==================================================================" | tee -a "$LOG_FILE"
    beeline -u "$HIVE_URL" --hiveconf run_id="$RUN_ID" -f "$script_path" 2>&1 | tee -a "$LOG_FILE"
}

# execution separee des 7 scripts SQL (1 seul -f par appel Beeline)
run_hive_script "01_sql_ddl/01_create_silver.sql"
run_hive_script "01_sql_ddl/00_load_csv_to_silver.sql"
run_hive_script "01_sql_ddl/02_create_gold.sql"
run_hive_script "01_sql_ddl/03_create_control.sql"
run_hive_script "02_sql_dml/01_load_dimensions_gold.sql"
run_hive_script "02_sql_dml/02_load_faits_gold.sql"
run_hive_script "02_sql_dml/03_data_quality_audit.sql"

# assemblage des sorties Hive en vrais fichiers CSV avec en-tetes
echo "nom_table_ou_metrique;volume" > 05_rapports/j7_tables_counts.csv
cat /tmp/j7_raw/tables_counts/* >> 05_rapports/j7_tables_counts.csv

echo "id_run;nom_table;nom_attribut;taux_completude;nb_doublons;nb_orphelins_fk" > 05_rapports/j7_integrite.csv
cat /tmp/j7_raw/integrite/* >> 05_rapports/j7_integrite.csv

echo "id_run;nom_job;source_donnees;empreinte_sha256;date_debut;date_fin;nb_lignes_lues;nb_lignes_chargees;nb_lignes_rejetees;statut" > 05_rapports/j7_publication_lots.csv
cat /tmp/j7_raw/publication_lots/* >> 05_rapports/j7_publication_lots.csv

echo "id_run;fichier_source;annee_campagne;type_enquete;finess_geo;finess;cle_rattachement;score_global_ajuste;nb_repondants;motif_quarantaine" > 05_rapports/j5_arbitrages_gold.csv
cat /tmp/j7_raw/j5_arbitrages_gold/* >> 05_rapports/j5_arbitrages_gold.csv

echo "annee_campagne;type_enquete;statut_rattachement;nb_enquetes_publiees" > 05_rapports/j5_rattachement_gold.csv
cat /tmp/j7_raw/j5_rattachement_gold/* >> 05_rapports/j5_rattachement_gold.csv

echo "[SUCCESS] Pipeline J07 termine. Fichiers generes dans 05_rapports/ (run_id=$RUN_ID)." | tee -a "$LOG_FILE"