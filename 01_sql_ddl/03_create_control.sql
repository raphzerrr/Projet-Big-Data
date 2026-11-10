-- creation de la base de controle et audit
create database if not exists chu_control;
use chu_control;

-- suivi des executions des lots avec empreinte sha256
create table if not exists journal_lots (
    id_run string,
    nom_job string,
    source_donnees string,
    empreinte_sha256 string,
    date_debut timestamp,
    date_fin timestamp,
    nb_lignes_lues bigint,
    nb_lignes_chargees bigint,
    nb_lignes_rejetees bigint,
    statut string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- stockage des anomalies et rejets
create table if not exists journal_rejets (
    id_run string,
    date_rejet timestamp,
    table_cible string,
    code_erreur string,
    cle_enregistrement string,
    detail_anomalie string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- metriques de qualite et d integrite
create table if not exists journal_qualite (
    id_run string,
    date_mesure timestamp,
    nom_table string,
    nom_attribut string,
    taux_completude decimal(5,2),
    nb_doublons bigint,
    nb_orphelins_fk bigint
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- mise en quarantaine des cles gold amigues de satisfaction (72 cles / 211 lignes)
create table if not exists quarantaine_satisfaction (
    id_run string,
    fichier_source string,
    annee_campagne int,
    type_enquete string,
    finess_geo string,
    finess string,
    cle_rattachement string,
    score_global_ajuste decimal(6,2),
    nb_repondants int,
    motif_quarantaine string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');