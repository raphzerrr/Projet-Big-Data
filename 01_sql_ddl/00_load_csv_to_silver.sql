-- chargement des fichiers csv talend vers les tables parquet chu_silver
use chu_silver;

-- 1. tables externes csv (lecture brute sur hdfs)
create external table if not exists ext_ref_commune_region (
    code_commune string,
    code_region string,
    nom_region string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/referentiels'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j1_etablissement (
    identifiant_organisation string,
    finess_site string,
    finess_etablissement_juridique string,
    raison_sociale_site string,
    code_commune string,
    code_postal string,
    commune string,
    siret_site string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j01_etablissement'
tblproperties ('skip.header.line.count'='1', 'serialization.encoding'='CP1252', 'serialization.null.format'='');

create external table if not exists ext_j2_prof (
    id_prof_source_hash string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j02_prof'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j2_prof_csv (
    id_prof_source_hash string,
    type_identifiant string,
    civilite_exercice string,
    categorie_pro string,
    profession string,
    specialite string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j02_prof_csv'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j2_bridge (
    id_prof_hash string,
    nb_organisations string,
    identifiant_organisation string,
    statut_affiliation string,
    mode_exercice string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j02_bridge'
tblproperties ('skip.header.line.count'='1', 'serialization.encoding'='CP1252', 'serialization.null.format'='');

create external table if not exists ext_j2_patient (
    id_patient_hash string,
    sexe string,
    tranche_age string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j02_patient'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j2_diagnostic (
    code_diag string,
    libelle_diagnostic string,
    categorie_pathologie string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j02_diagnostic'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j3_consultation (
    num_consultation_source string,
    sk_temps string,
    id_patient_hash string,
    id_prof_source_hash string,
    code_diag string,
    nb_consultations string,
    duree_consultation_min string,
    statut_duree string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j03_consultation'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j4_hospitalisation (
    num_hosp_source string,
    sk_temps_entree string,
    id_patient_hash string,
    identifiant_organisation string,
    code_diag string,
    suite_consultation string,
    nb_hospitalisations string,
    duree_sejour_jours string,
    statut_duree string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j04_hospitalisation'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');

create external table if not exists ext_j5_satisfaction (
    fichier_source string,
    annee_campagne string,
    sk_temps string,
    type_enquete string,
    finess_geo string,
    finess string,
    cle_rattachement string,
    score_global_ajuste string,
    nb_repondants string,
    taux_recommandation string,
    nb_repondants_reco string,
    statut_mesure string,
    depot_source string,
    participation_source string,
    region_source string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j05_satisfaction'
tblproperties ('skip.header.line.count'='1', 'serialization.encoding'='CP1252', 'serialization.null.format'='');

create external table if not exists ext_j6_deces (
    sk_temps_deces string,
    code_region string,
    sexe_decede string,
    tranche_age_deces string,
    nb_deces string
)
row format delimited fields terminated by ';'
stored as textfile
location '/chu/staging/j06_deces'
tblproperties ('skip.header.line.count'='1', 'serialization.null.format'='');


-- 2. alimentation typee et nettoyee dans les tables silver parquet
insert overwrite table ref_commune_region
select
    trim(regexp_replace(code_commune, '^\\uFEFF', '')),
    trim(code_region),
    trim(nom_region)
from ext_ref_commune_region
where trim(code_commune) is not null and trim(code_commune) <> '';

insert overwrite table silver_etablissement
select
    nullif(trim(regexp_replace(identifiant_organisation, '^\\uFEFF', '')), ''),
    nullif(trim(finess_site), ''),
    nullif(trim(finess_etablissement_juridique), ''),
    nullif(trim(raison_sociale_site), ''),
    nullif(trim(code_commune), ''),
    nullif(trim(code_postal), ''),
    nullif(trim(commune), ''),
    nullif(trim(siret_site), '')
from ext_j1_etablissement
where nullif(trim(finess_site), '') is not null;

insert overwrite table silver_professionnel
select
    nullif(trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')), ''),
    nullif(trim(civilite_exercice), ''),
    nullif(trim(categorie_pro), ''),
    nullif(trim(profession), ''),
    nullif(trim(specialite), '')
from ext_j2_prof
where nullif(trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_professionnel_csv
select
    nullif(trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')), ''),
    nullif(trim(type_identifiant), ''),
    nullif(trim(civilite_exercice), ''),
    nullif(trim(categorie_pro), ''),
    nullif(trim(profession), ''),
    nullif(trim(specialite), '')
from ext_j2_prof_csv
where nullif(trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_bridge_prof_org
select
    nullif(trim(regexp_replace(id_prof_hash, '^\\uFEFF', '')), ''),
    cast(trim(nb_organisations) as int),
    nullif(trim(identifiant_organisation), ''),
    nullif(trim(statut_affiliation), ''),
    nullif(trim(mode_exercice), '')
from ext_j2_bridge
where nullif(trim(regexp_replace(id_prof_hash, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_patient
select
    nullif(trim(regexp_replace(id_patient_hash, '^\\uFEFF', '')), ''),
    nullif(trim(sexe), ''),
    nullif(trim(tranche_age), '')
from ext_j2_patient
where nullif(trim(regexp_replace(id_patient_hash, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_diagnostic
select
    nullif(trim(regexp_replace(code_diag, '^\\uFEFF', '')), ''),
    nullif(trim(libelle_diagnostic), ''),
    nullif(trim(categorie_pathologie), '')
from ext_j2_diagnostic
where nullif(trim(regexp_replace(code_diag, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_consultation
select
    nullif(trim(regexp_replace(num_consultation_source, '^\\uFEFF', '')), ''),
    cast(trim(sk_temps) as int),
    nullif(trim(id_patient_hash), ''),
    nullif(trim(id_prof_source_hash), ''),
    nullif(trim(code_diag), ''),
    coalesce(cast(trim(nb_consultations) as int), 1),
    cast(regexp_replace(trim(duree_consultation_min), ',', '.') as decimal(9,2)),
    nullif(trim(statut_duree), '')
from ext_j3_consultation
where nullif(trim(regexp_replace(num_consultation_source, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_hospitalisation
select
    nullif(trim(regexp_replace(num_hosp_source, '^\\uFEFF', '')), ''),
    cast(trim(sk_temps_entree) as int),
    nullif(trim(id_patient_hash), ''),
    nullif(trim(identifiant_organisation), ''),
    nullif(trim(code_diag), ''),
    nullif(trim(suite_consultation), ''),
    coalesce(cast(trim(nb_hospitalisations) as int), 1),
    cast(trim(duree_sejour_jours) as int),
    nullif(trim(statut_duree), '')
from ext_j4_hospitalisation
where nullif(trim(regexp_replace(num_hosp_source, '^\\uFEFF', '')), '') is not null;

insert overwrite table silver_satisfaction
select
    nullif(trim(regexp_replace(fichier_source, '^\\uFEFF', '')), ''),
    cast(trim(annee_campagne) as int),
    cast(trim(sk_temps) as int),
    nullif(trim(type_enquete), ''),
    nullif(trim(finess_geo), ''),
    nullif(trim(finess), ''),
    nullif(trim(cle_rattachement), ''),
    cast(regexp_replace(trim(score_global_ajuste), ',', '.') as decimal(6,2)),
    cast(trim(nb_repondants) as int),
    cast(regexp_replace(trim(taux_recommandation), ',', '.') as decimal(6,2)),
    cast(trim(nb_repondants_reco) as int),
    nullif(trim(statut_mesure), ''),
    nullif(trim(depot_source), ''),
    nullif(trim(participation_source), ''),
    nullif(trim(region_source), '')
from ext_j5_satisfaction
where cast(trim(annee_campagne) as int) is not null;

insert overwrite table silver_deces
select
    cast(trim(regexp_replace(sk_temps_deces, '^\\uFEFF', '')) as int),
    nullif(trim(code_region), ''),
    nullif(trim(sexe_decede), ''),
    nullif(trim(tranche_age_deces), ''),
    cast(trim(nb_deces) as bigint)
from ext_j6_deces
where cast(trim(regexp_replace(sk_temps_deces, '^\\uFEFF', '')) as int) is not null;