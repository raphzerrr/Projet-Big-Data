-- creation base de controle et audit
create database if not exists chu_control;
use chu_control;

-- suivi des executions des jobs talend
create table if not exists journal_lots (
    id_run string,
    nom_job string,
    source_donnees string,
    date_debut timestamp,
    date_fin timestamp,
    nb_lignes_lues bigint,
    nb_lignes_chargees bigint,
    nb_lignes_rejetees bigint,
    statut string
) stored as parquet;

-- stockage des anomalies et rejets (finess, dates, doublons)
create table if not exists journal_rejets (
    id_run string,
    date_rejet timestamp,
    table_cible string,
    code_erreur string,
    cle_enregistrement string,
    detail_anomalie string
) stored as parquet;

-- metriques de qualite et taux de completude
create table if not exists journal_qualite (
    id_run string,
    date_mesure timestamp,
    nom_table string,
    nom_attribut string,
    taux_completude decimal(5,2),
    nb_doublons bigint,
    nb_orphelins_fk bigint
) stored as parquet;