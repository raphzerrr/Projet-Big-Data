-- chargement des fichiers csv talend vers les tables parquet chu_silver (compatible hive 1.1)
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


-- 2. alimentation typee et nettoyee dans les tables silver parquet (sans fonction nullif)
insert overwrite table ref_commune_region
select
    case when trim(regexp_replace(code_commune, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(code_commune, '^\\uFEFF', '')) end,
    case when trim(code_region) = '' then cast(null as string) else trim(code_region) end,
    case when trim(nom_region) = '' then cast(null as string) else trim(nom_region) end
from ext_ref_commune_region
where trim(regexp_replace(code_commune, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(code_commune, '^\\uFEFF', '')) <> '';

-- conservation de toutes les lignes j01 en silver meme sans finess_site
insert overwrite table silver_etablissement
select
    case when trim(regexp_replace(identifiant_organisation, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(identifiant_organisation, '^\\uFEFF', '')) end,
    case when trim(finess_site) = '' then cast(null as string) else trim(finess_site) end,
    case when trim(finess_etablissement_juridique) = '' then cast(null as string) else trim(finess_etablissement_juridique) end,
    case when trim(raison_sociale_site) = '' then cast(null as string) else trim(raison_sociale_site) end,
    case when trim(code_commune) = '' then cast(null as string) else trim(code_commune) end,
    case when trim(code_postal) = '' then cast(null as string) else trim(code_postal) end,
    case when trim(commune) = '' then cast(null as string) else trim(commune) end,
    case when trim(siret_site) = '' then cast(null as string) else trim(siret_site) end
from ext_j1_etablissement
where (identifiant_organisation is not null and trim(regexp_replace(identifiant_organisation, '^\\uFEFF', '')) <> '')
   or (finess_site is not null and trim(finess_site) <> '');

insert overwrite table silver_professionnel
select
    case when trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) end,
    case when trim(civilite_exercice) = '' then cast(null as string) else trim(civilite_exercice) end,
    case when trim(categorie_pro) = '' then cast(null as string) else trim(categorie_pro) end,
    case when trim(profession) = '' then cast(null as string) else trim(profession) end,
    case when trim(specialite) = '' then cast(null as string) else trim(specialite) end
from ext_j2_prof
where trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) <> '';

insert overwrite table silver_professionnel_csv
select
    case when trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) end,
    case when trim(type_identifiant) = '' then cast(null as string) else trim(type_identifiant) end,
    case when trim(civilite_exercice) = '' then cast(null as string) else trim(civilite_exercice) end,
    case when trim(categorie_pro) = '' then cast(null as string) else trim(categorie_pro) end,
    case when trim(profession) = '' then cast(null as string) else trim(profession) end,
    case when trim(specialite) = '' then cast(null as string) else trim(specialite) end
from ext_j2_prof_csv
where trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(id_prof_source_hash, '^\\uFEFF', '')) <> '';

insert overwrite table silver_bridge_prof_org
select
    case when trim(regexp_replace(id_prof_hash, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(id_prof_hash, '^\\uFEFF', '')) end,
    cast(trim(nb_organisations) as int),
    case when trim(identifiant_organisation) = '' then cast(null as string) else trim(identifiant_organisation) end,
    case when trim(statut_affiliation) = '' then cast(null as string) else trim(statut_affiliation) end,
    case when trim(mode_exercice) = '' then cast(null as string) else trim(mode_exercice) end
from ext_j2_bridge
where trim(regexp_replace(id_prof_hash, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(id_prof_hash, '^\\uFEFF', '')) <> '';

insert overwrite table silver_patient
select
    case when trim(regexp_replace(id_patient_hash, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(id_patient_hash, '^\\uFEFF', '')) end,
    case when trim(sexe) = '' then cast(null as string) else trim(sexe) end,
    case when trim(tranche_age) = '' then cast(null as string) else trim(tranche_age) end
from ext_j2_patient
where trim(regexp_replace(id_patient_hash, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(id_patient_hash, '^\\uFEFF', '')) <> '';

insert overwrite table silver_diagnostic
select
    case when trim(regexp_replace(code_diag, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(code_diag, '^\\uFEFF', '')) end,
    case when trim(libelle_diagnostic) = '' then cast(null as string) else trim(libelle_diagnostic) end,
    case when trim(categorie_pathologie) = '' then cast(null as string) else trim(categorie_pathologie) end
from ext_j2_diagnostic
where trim(regexp_replace(code_diag, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(code_diag, '^\\uFEFF', '')) <> '';

insert overwrite table silver_consultation
select
    case when trim(regexp_replace(num_consultation_source, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(num_consultation_source, '^\\uFEFF', '')) end,
    cast(trim(sk_temps) as int),
    case when trim(id_patient_hash) = '' then cast(null as string) else trim(id_patient_hash) end,
    case when trim(id_prof_source_hash) = '' then cast(null as string) else trim(id_prof_source_hash) end,
    case when trim(code_diag) = '' then cast(null as string) else trim(code_diag) end,
    coalesce(cast(trim(nb_consultations) as int), 1),
    case when trim(duree_consultation_min) = '' then cast(null as decimal(9,2)) else cast(regexp_replace(trim(duree_consultation_min), ',', '.') as decimal(9,2)) end,
    case when trim(statut_duree) = '' then cast(null as string) else trim(statut_duree) end
from ext_j3_consultation
where trim(regexp_replace(num_consultation_source, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(num_consultation_source, '^\\uFEFF', '')) <> '';

insert overwrite table silver_hospitalisation
select
    case when trim(regexp_replace(num_hosp_source, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(num_hosp_source, '^\\uFEFF', '')) end,
    cast(trim(sk_temps_entree) as int),
    case when trim(id_patient_hash) = '' then cast(null as string) else trim(id_patient_hash) end,
    case when trim(identifiant_organisation) = '' then cast(null as string) else trim(identifiant_organisation) end,
    case when trim(code_diag) = '' then cast(null as string) else trim(code_diag) end,
    case when trim(suite_consultation) = '' then cast(null as string) else trim(suite_consultation) end,
    coalesce(cast(trim(nb_hospitalisations) as int), 1),
    case when trim(duree_sejour_jours) = '' then cast(null as int) else cast(trim(duree_sejour_jours) as int) end,
    case when trim(statut_duree) = '' then cast(null as string) else trim(statut_duree) end
from ext_j4_hospitalisation
where trim(regexp_replace(num_hosp_source, '^\\uFEFF', '')) is not null
  and trim(regexp_replace(num_hosp_source, '^\\uFEFF', '')) <> '';

insert overwrite table silver_satisfaction
select
    case when trim(regexp_replace(fichier_source, '^\\uFEFF', '')) = '' then cast(null as string) else trim(regexp_replace(fichier_source, '^\\uFEFF', '')) end,
    cast(trim(annee_campagne) as int),
    cast(trim(sk_temps) as int),
    case when trim(type_enquete) = '' then cast(null as string) else trim(type_enquete) end,
    case when trim(finess_geo) = '' then cast(null as string) else trim(finess_geo) end,
    case when trim(finess) = '' then cast(null as string) else trim(finess) end,
    case when trim(cle_rattachement) = '' then cast(null as string) else trim(cle_rattachement) end,
    case when trim(score_global_ajuste) = '' then cast(null as decimal(6,2)) else cast(regexp_replace(trim(score_global_ajuste), ',', '.') as decimal(6,2)) end,
    case when trim(nb_repondants) = '' then cast(null as int) else cast(trim(nb_repondants) as int) end,
    case when trim(taux_recommandation) = '' then cast(null as decimal(6,2)) else cast(regexp_replace(trim(taux_recommandation), ',', '.') as decimal(6,2)) end,
    case when trim(nb_repondants_reco) = '' then cast(null as int) else cast(trim(nb_repondants_reco) as int) end,
    case when trim(statut_mesure) = '' then cast(null as string) else trim(statut_mesure) end,
    case when trim(depot_source) = '' then cast(null as string) else trim(depot_source) end,
    case when trim(participation_source) = '' then cast(null as string) else trim(participation_source) end,
    case when trim(region_source) = '' then cast(null as string) else trim(region_source) end
from ext_j5_satisfaction
where cast(trim(annee_campagne) as int) is not null;

insert overwrite table silver_deces
select
    cast(trim(regexp_replace(sk_temps_deces, '^\\uFEFF', '')) as int),
    case when trim(code_region) = '' then cast(null as string) else trim(code_region) end,
    case when trim(sexe_decede) = '' then cast(null as string) else trim(sexe_decede) end,
    case when trim(tranche_age_deces) = '' then cast(null as string) else trim(tranche_age_deces) end,
    cast(trim(nb_deces) as bigint)
from ext_j6_deces
where cast(trim(regexp_replace(sk_temps_deces, '^\\uFEFF', '')) as int) is not null;