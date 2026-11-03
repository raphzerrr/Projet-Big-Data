-- creation de la base de donnees gold
create database if not exists chu_gold;
use chu_gold;

-- dimension temps
create table if not exists dim_temps (
    sk_temps int,
    date_complete date,
    annee smallint,
    trimestre smallint,
    mois smallint,
    nom_mois string,
    jour smallint
)
stored as parquet;

-- dimension region
create table if not exists dim_region (
    sk_region int,
    code_insee_region string,
    nom_region string
)
stored as parquet;

-- dimension etablissement
create table if not exists dim_etablissement (
    sk_etablissement int,
    identifiant_organisation string,
    num_finess_site string,
    num_finess_ej string,
    siret_site string,
    raison_sociale string,
    code_postal string,
    code_commune string,
    sk_region int
)
stored as parquet;

-- dimension patient
create table if not exists dim_patient (
    sk_patient bigint,
    id_patient_hash string,
    sexe string,
    tranche_age string
)
clustered by (sk_patient) into 8 buckets
stored as parquet;

-- dimension diagnostic
create table if not exists dim_diagnostic (
    sk_diagnostic int,
    code_diag string,
    libelle_diagnostic string,
    categorie_pathologie string
)
stored as parquet;

-- dimension professionnel
create table if not exists dim_professionnel (
    sk_professionnel int,
    id_prof_source_hash string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string,
    mode_exercice string
)
stored as parquet;

-- fait consultation avec partitionnement par annee et bucketing patient
-- le bucketing sur sk_patient correspond a celui de dim_patient pour optimiser les jointures
create table if not exists fait_consultation (
    id_fait_consultation bigint,
    num_consultation_source string,
    sk_temps int,
    sk_patient bigint,
    sk_etablissement int,
    sk_professionnel int,
    sk_diagnostic int,
    nb_consultations int,
    duree_consultation_min decimal(9,2)
)
partitioned by (annee int)
clustered by (sk_patient) into 8 buckets
stored as parquet;

-- fait hospitalisation avec partitionnement par annee d entree
create table if not exists fait_hospitalisation (
    id_fait_hospitalisation bigint,
    num_hosp_source string,
    sk_temps_entree int,
    sk_patient bigint,
    sk_etablissement int,
    sk_diagnostic int,
    suite_consultation string,
    nb_hospitalisations int,
    duree_sejour_jours int
)
partitioned by (annee_entree int)
clustered by (sk_patient) into 8 buckets
stored as parquet;

-- fait deces avec partitionnement temporel
-- partitionnement vital pour isoler rapidement les requetes sur l annee 2019
create table if not exists fait_deces (
    id_fait_deces bigint,
    sk_temps_deces int,
    sk_region int,
    sexe_decede string,
    tranche_age_deces string,
    nb_deces bigint
)
partitioned by (annee int)
stored as parquet;

-- fait satisfaction partitionne par campagne
create table if not exists fait_satisfaction (
    id_fait_satisfaction bigint,
    sk_temps int,
    sk_etablissement int,
    type_enquete string,
    score_global_ajuste decimal(6,2),
    nb_repondants int,
    taux_recommandation decimal(6,2),
    nb_repondants_reco int
)
partitioned by (annee_campagne int)
stored as parquet;