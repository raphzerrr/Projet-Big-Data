create database if not exists chu_silver;
use chu_silver;

create table if not exists ref_commune_region (
    code_commune string,
    code_region string,
    nom_region string
) stored as parquet;

create table if not exists silver_patient (
    id_patient_hash string,
    sexe string,
    tranche_age string
) stored as parquet;

create table if not exists silver_professionnel (
    id_prof_source_hash string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string,
    mode_exercice string
) stored as parquet;

create table if not exists silver_etablissement (
    identifiant_organisation string,
    num_finess_site string,
    num_finess_ej string,
    siret_site string,
    raison_sociale string,
    code_postal string,
    code_commune string
) stored as parquet;

create table if not exists silver_diagnostic (
    code_diag string,
    libelle_diagnostic string,
    categorie_pathologie string
) stored as parquet;

create table if not exists silver_consultation (
    num_consultation_source string,
    date_consultation date,
    id_patient_hash string,
    id_prof_source_hash string,
    code_diag string,
    duree_consultation_min decimal(9,2)
) stored as parquet;

create table if not exists silver_hospitalisation (
    num_hosp_source string,
    date_entree date,
    id_patient_hash string,
    identifiant_organisation string,
    code_diagnostic string,
    suite_consultation string,
    duree_sejour_jours int
) stored as parquet;

create table if not exists silver_deces (
    date_deces date,
    code_lieu_deces string,
    sexe string,
    tranche_age string,
    nb_deces bigint
) stored as parquet;

create table if not exists silver_satisfaction (
    annee_campagne int,
    finess string,
    type_enquete string,
    score_global_ajuste decimal(6,2),
    nb_repondants int,
    taux_recommandation decimal(6,2),
    nb_repondants_reco int
) stored as parquet;