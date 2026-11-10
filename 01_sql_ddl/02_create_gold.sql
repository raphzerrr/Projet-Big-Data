-- creation de la base de donnees gold
create database if not exists chu_gold;
use chu_gold;

-- 1. dimensions
create table if not exists dim_temps (
    sk_temps int,
    date_complete date,
    annee smallint,
    trimestre smallint,
    mois smallint,
    nom_mois string,
    jour smallint
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

create table if not exists dim_region (
    sk_region int,
    code_insee_region string,
    nom_region string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

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
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

create table if not exists dim_patient (
    sk_patient bigint,
    id_patient_hash string,
    sexe string,
    tranche_age string
)
clustered by (sk_patient) into 8 buckets
stored as parquet tblproperties ('parquet.compress'='SNAPPY');

create table if not exists dim_diagnostic (
    sk_diagnostic int,
    code_diag string,
    libelle_diagnostic string,
    categorie_pathologie string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

create table if not exists dim_professionnel (
    sk_professionnel int,
    id_prof_source_hash string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string,
    mode_exercice string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- 2. tables de faits
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
stored as parquet tblproperties ('parquet.compress'='SNAPPY');

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
stored as parquet tblproperties ('parquet.compress'='SNAPPY');

create table if not exists fait_deces (
    id_fait_deces bigint,
    sk_temps_deces int,
    sk_region int,
    sexe_decede string,
    tranche_age_deces string,
    nb_deces bigint
)
partitioned by (annee int)
stored as parquet tblproperties ('parquet.compress'='SNAPPY');

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
stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- 3. vues metier pour power bi (j07 - sans nullif pour compatibilite hive 1.1)
create or replace view v_kpi_deces_region as
select
    f.annee,
    r.code_insee_region,
    r.nom_region,
    f.sexe_decede,
    f.tranche_age_deces,
    sum(f.nb_deces) as total_deces
from chu_gold.fait_deces f
join chu_gold.dim_region r on f.sk_region = r.sk_region
group by f.annee, r.code_insee_region, r.nom_region, f.sexe_decede, f.tranche_age_deces;

create or replace view v_kpi_satisfaction_region as
select
    s.annee_campagne,
    r.code_insee_region,
    r.nom_region,
    s.type_enquete,
    round(
        sum(s.score_global_ajuste * s.nb_repondants) /
        case when sum(s.nb_repondants) = 0 then cast(null as bigint) else sum(s.nb_repondants) end,
    2) as score_moyen_pondere,
    sum(s.nb_repondants) as total_repondants
from chu_gold.fait_satisfaction s
join chu_gold.dim_etablissement e on s.sk_etablissement = e.sk_etablissement
join chu_gold.dim_region r on e.sk_region = r.sk_region
where s.score_global_ajuste is not null and s.nb_repondants > 0
group by s.annee_campagne, r.code_insee_region, r.nom_region, s.type_enquete;

create or replace view v_kpi_activite_etablissement as
select
    c.annee,
    e.num_finess_site,
    e.raison_sociale,
    r.nom_region,
    sum(c.nb_consultations) as total_consultations,
    round(avg(c.duree_consultation_min), 2) as duree_moyenne_consultation_min
from chu_gold.fait_consultation c
join chu_gold.dim_etablissement e on c.sk_etablissement = e.sk_etablissement
join chu_gold.dim_region r on e.sk_region = r.sk_region
group by c.annee, e.num_finess_site, e.raison_sociale, r.nom_region;