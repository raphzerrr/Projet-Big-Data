-- ============================================================================
-- KIT DE BENCHMARK - ETAPE 1 : PREPARATION DES ENVIRONNEMENTS AVANT / APRES
-- ============================================================================

-- 1. creation d une base dediee aux tables non optimisees (etat AVANT)
create database if not exists chu_gold_non_opti;
use chu_gold_non_opti;

-- table consultation sans partitionnement ni bucketing et en textfile
create table if not exists fait_consultation_non_opti (
    id_fait_consultation bigint,
    num_consultation_source string,
    sk_temps int,
    sk_patient bigint,
    sk_etablissement int,
    sk_professionnel int,
    sk_diagnostic int,
    nb_consultations int,
    duree_consultation_min decimal(9,2),
    annee int
) stored as textfile;

insert overwrite table fait_consultation_non_opti
select * from chu_gold.fait_consultation;

-- table hospitalisation sans partitionnement ni bucketing et en textfile
create table if not exists fait_hospitalisation_non_opti (
    id_fait_hospitalisation bigint,
    num_hosp_source string,
    sk_temps_entree int,
    sk_patient bigint,
    sk_etablissement int,
    sk_diagnostic int,
    suite_consultation string,
    nb_hospitalisations int,
    duree_sejour_jours int,
    annee_entree int
) stored as textfile;

insert overwrite table fait_hospitalisation_non_opti
select * from chu_gold.fait_hospitalisation;

-- table deces sans partitionnement et en textfile
create table if not exists fait_deces_non_opti (
    id_fait_deces bigint,
    sk_temps_deces int,
    sk_region int,
    sexe_decede string,
    tranche_age_deces string,
    nb_deces bigint,
    annee int
) stored as textfile;

insert overwrite table fait_deces_non_opti
select * from chu_gold.fait_deces;

-- table satisfaction sans partitionnement et en textfile
create table if not exists fait_satisfaction_non_opti (
    id_fait_satisfaction bigint,
    sk_temps int,
    sk_etablissement int,
    type_enquete string,
    score_global_ajuste decimal(6,2),
    nb_repondants int,
    taux_recommandation decimal(6,2),
    nb_repondants_reco int,
    annee_campagne int
) stored as textfile;

insert overwrite table fait_satisfaction_non_opti
select * from chu_gold.fait_satisfaction;

-- table patient sans bucketing et en textfile
create table if not exists dim_patient_non_opti (
    sk_patient bigint,
    id_patient_hash string,
    sexe string,
    tranche_age string
) stored as textfile;

insert overwrite table dim_patient_non_opti
select * from chu_gold.dim_patient;


-- 2. calcul des statistiques sur la base optimisee chu_gold (etat APRES)
use chu_gold;

analyze table dim_temps compute statistics for columns;
analyze table dim_region compute statistics for columns;
analyze table dim_etablissement compute statistics for columns;
analyze table dim_patient compute statistics for columns;
analyze table dim_diagnostic compute statistics for columns;
analyze table dim_professionnel compute statistics for columns;

analyze table fait_consultation partition(annee) compute statistics for columns;
analyze table fait_hospitalisation partition(annee_entree) compute statistics for columns;
analyze table fait_deces partition(annee) compute statistics for columns;
analyze table fait_satisfaction partition(annee_campagne) compute statistics for columns;