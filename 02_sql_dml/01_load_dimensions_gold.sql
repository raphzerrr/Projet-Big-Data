-- configuration hive pour forcer le respect des buckets a l insertion
set hive.enforce.bucketing = true;

use chu_gold;

-- chargement de dim_temps a partir des dates distinctes observees dans silver
insert overwrite table dim_temps
select distinct
    cast(date_format(d.date_cal, 'yyyyMMdd') as int) as sk_temps,
    d.date_cal as date_complete,
    cast(year(d.date_cal) as smallint) as annee,
    cast(quarter(d.date_cal) as smallint) as trimestre,
    cast(month(d.date_cal) as smallint) as mois,
    date_format(d.date_cal, 'MMMM') as nom_mois,
    cast(day(d.date_cal) as smallint) as jour
from (
    select date_consultation as date_cal from chu_silver.silver_consultation where date_consultation is not null
    union
    select date_entree as date_cal from chu_silver.silver_hospitalisation where date_entree is not null
    union
    select to_date(concat(cast(year(date_deces) as string), '-12-31')) as date_cal from chu_silver.silver_deces where date_deces is not null
    union
    select to_date(concat(cast(annee_campagne as string), '-12-31')) as date_cal from chu_silver.silver_satisfaction where annee_campagne is not null
) d;

-- chargement de dim_region avec le membre technique 0 (inconnue)
insert overwrite table dim_region
select 0 as sk_region, '00' as code_insee_region, 'INCONNUE' as nom_region
union all
select
    row_number() over (order by code_region) as sk_region,
    code_region as code_insee_region,
    nom_region
from (
    select distinct code_region, nom_region
    from chu_silver.ref_commune_region
    where code_region is not null
) r;

-- chargement de dim_etablissement avec le membre technique 0 et jointure region
insert overwrite table dim_etablissement
select
    0 as sk_etablissement,
    'INCONNU' as identifiant_organisation,
    '000000000' as num_finess_site,
    '000000000' as num_finess_ej,
    '00000000000000' as siret_site,
    'INCONNU' as raison_sociale,
    '00000' as code_postal,
    '00000' as code_commune,
    0 as sk_region
union all
select
    row_number() over (order by e.num_finess_site, e.identifiant_organisation) as sk_etablissement,
    e.identifiant_organisation,
    e.num_finess_site,
    e.num_finess_ej,
    e.siret_site,
    coalesce(e.raison_sociale, 'NON_RENSEIGNE') as raison_sociale,
    e.code_postal,
    e.code_commune,
    coalesce(reg.sk_region, 0) as sk_region
from chu_silver.silver_etablissement e
left join chu_silver.ref_commune_region cog
    on e.code_commune = cog.code_commune
left join chu_gold.dim_region reg
    on cog.code_region = reg.code_insee_region;

-- chargement de dim_patient (redistribue automatiquement dans les 8 buckets)
insert overwrite table dim_patient
select
    cast(0 as bigint) as sk_patient,
    'INCONNU' as id_patient_hash,
    'INC' as sexe,
    'INC' as tranche_age
union all
select
    cast(row_number() over (order by id_patient_hash) as bigint) as sk_patient,
    id_patient_hash,
    coalesce(sexe, 'INC') as sexe,
    coalesce(tranche_age, 'INC') as tranche_age
from chu_silver.silver_patient
where id_patient_hash is not null;

-- chargement de dim_diagnostic avec le membre technique 0
insert overwrite table dim_diagnostic
select
    0 as sk_diagnostic,
    'INCONNU' as code_diag,
    'NON_RENSEIGNE' as libelle_diagnostic,
    'INCONNU' as categorie_pathologie
union all
select
    row_number() over (order by code_diag) as sk_diagnostic,
    code_diag,
    coalesce(libelle_diagnostic, 'NON_RENSEIGNE') as libelle_diagnostic,
    coalesce(categorie_pathologie, 'NON_CIM10') as categorie_pathologie
from chu_silver.silver_diagnostic
where code_diag is not null;

-- chargement de dim_professionnel avec le membre technique 0
insert overwrite table dim_professionnel
select
    0 as sk_professionnel,
    'INCONNU' as id_prof_source_hash,
    'NR' as civilite_exercice,
    'NR' as categorie_pro,
    'NR' as profession,
    'NR' as specialite,
    'NR' as mode_exercice
union all
select
    row_number() over (order by id_prof_source_hash) as sk_professionnel,
    id_prof_source_hash,
    coalesce(civilite_exercice, 'NR') as civilite_exercice,
    coalesce(categorie_pro, 'NR') as categorie_pro,
    coalesce(profession, 'NR') as profession,
    coalesce(specialite, 'NR') as specialite,
    coalesce(mode_exercice, 'NR') as mode_exercice
from chu_silver.silver_professionnel
where id_prof_source_hash is not null;