#!/bin/bash
# ============================================================================
# ORCHESTRATION J07 : EXECUTION HIVE ET GENERATION DES 4 FICHIERS D AUDIT
# ============================================================================

mkdir -p /tmp/j7_raw
mkdir -p 05_rapports

# execution complete des scripts SQL avec capture du log d'execution
beeline -u "jdbc:hive2://localhost:10000" \
  -f 01_sql_ddl/01_create_silver.sql \
  -f 01_sql_ddl/00_load_csv_to_silver.sql \
  -f 01_sql_ddl/02_create_gold.sql \
  -f 01_sql_ddl/03_create_control.sql \
  -f 02_sql_dml/01_load_dimensions_gold.sql \
  -f 02_sql_dml/02_load_faits_gold.sql \
  -f 02_sql_dml/03_data_quality_audit.sql \
  2>&1 | tee 05_rapports/j7_execution_hive.log

# assemblage des sorties Hive en vrais fichiers CSV avec en-tetes
echo "nom_table_ou_metrique;volume" > 05_rapports/j7_tables_counts.csv
cat /tmp/j7_raw/tables_counts/* >> 05_rapports/j7_tables_counts.csv

echo "id_run;nom_table;nom_attribut;taux_completude;nb_doublons;nb_orphelins_fk" > 05_rapports/j7_integrite.csv
cat /tmp/j7_raw/integrite/* >> 05_rapports/j7_integrite.csv

echo "id_run;nom_job;source_donnees;empreinte_sha256;date_debut;date_fin;nb_lignes_lues;nb_lignes_chargees;nb_lignes_rejetees;statut" > 05_rapports/j7_publication_lots.csv
cat /tmp/j7_raw/publication_lots/* >> 05_rapports/j7_publication_lots.csv

echo "Export termine : les 4 fichiers j7_*.csv et .log sont disponibles dans 05_rapports/"