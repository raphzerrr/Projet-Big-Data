-- creation de la base silver
create database if not exists chu_silver;
use chu_silver;

-- referentiel geographique cog 2020 (ref_commune_region.csv)
create table if not exists ref_commune_region (
    code_commune string,
    code_region string,
    nom_region string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j01 : etablissements de sante (j1_clean.csv)
create table if not exists silver_etablissement (
    identifiant_organisation string,
    finess_site string,
    finess_etablissement_juridique string,
    raison_sociale_site string,
    code_commune string,
    code_postal string,
    commune string,
    siret_site string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j02 : professionnels de sante postgresql (j2_clean.csv)
create table if not exists silver_professionnel (
    id_prof_source_hash string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j02 : professionnels de sante issus du csv referentiel (j2_pro_csv_clean.csv)
create table if not exists silver_professionnel_csv (
    id_prof_source_hash string,
    type_identifiant string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j02 : table de pont professionnel vers organisation (j2_bridge_prof_org.csv)
create table if not exists silver_bridge_prof_org (
    id_prof_hash string,
    nb_organisations int,
    identifiant_organisation string,
    statut_affiliation string,
    mode_exercice string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j02bis : patients pseudonymises (j2_patient_clean.csv - optionnel si non extrait)
create table if not exists silver_patient (
    id_patient_hash string,
    sexe string,
    tranche_age string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j02bis : referentiel diagnostics (j2_diagnostic_clean.csv - optionnel si non extrait)
create table if not exists silver_diagnostic (
    code_diag string,
    libelle_diagnostic string,
    categorie_pathologie string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j03 : consultations (j3_silver.csv)
create table if not exists silver_consultation (
    num_consultation_source string,
    sk_temps int,
    id_patient_hash string,
    id_prof_source_hash string,
    code_diag string,
    nb_consultations int,
    duree_consultation_min decimal(9,2),
    statut_duree string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j04 : hospitalisations (j4_silver.csv)
create table if not exists silver_hospitalisation (
    num_hosp_source string,
    sk_temps_entree int,
    id_patient_hash string,
    identifiant_organisation string,
    code_diag string,
    suite_consultation string,
    nb_hospitalisations int,
    duree_sejour_jours int,
    statut_duree string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j05 : satisfaction esatis (j5_silver.csv)
create table if not exists silver_satisfaction (
    fichier_source string,
    annee_campagne int,
    sk_temps int,
    type_enquete string,
    finess_geo string,
    finess string,
    cle_rattachement string,
    score_global_ajuste decimal(6,2),
    nb_repondants int,
    taux_recommandation decimal(6,2),
    nb_repondants_reco int,
    statut_mesure string,
    depot_source string,
    participation_source string,
    region_source string
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');

-- j06 : deces insee deja agreges (j6_silver.csv)
create table if not exists silver_deces (
    sk_temps_deces int,
    code_region string,
    sexe_decede string,
    tranche_age_deces string,
    nb_deces bigint
) stored as parquet tblproperties ('parquet.compress'='SNAPPY');