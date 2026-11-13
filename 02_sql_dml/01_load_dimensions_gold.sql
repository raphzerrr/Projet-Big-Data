-- configuration hive pour les buckets
set hive.enforce.bucketing = true;

use chu_gold;

-- 1. chargement de dim_temps depuis les cles sk_temps (compatible hive 1.1 : union all + distinct)
insert overwrite table dim_temps
select
    0 as sk_temps,
    cast('1900-01-01' as date) as date_complete,
    cast(1900 as smallint) as annee,
    cast(1 as smallint) as trimestre,
    cast(1 as smallint) as mois,
    'INCONNU' as nom_mois,
    cast(1 as smallint) as jour
union all
select
    t.sk_temps,
    t.date_cal as date_complete,
    cast(year(t.date_cal) as smallint) as annee,
    cast(quarter(t.date_cal) as smallint) as trimestre,
    cast(month(t.date_cal) as smallint) as mois,
    case month(t.date_cal)
        when 1 then 'Janvier' when 2 then 'Fevrier' when 3 then 'Mars'
        when 4 then 'Avril' when 5 then 'Mai' when 6 then 'Juin'
        when 7 then 'Juillet' when 8 then 'Aout' when 9 then 'Septembre'
        when 10 then 'Octobre' when 11 then 'Novembre' when 12 then 'Decembre'
    end as nom_mois,
    cast(day(t.date_cal) as smallint) as jour
from (
    select
        sk_temps,
        to_date(from_unixtime(unix_timestamp(cast(sk_temps as string), 'yyyyMMdd'))) as date_cal
    from (
        select distinct sk_temps
        from (
            select sk_temps from chu_silver.silver_consultation where sk_temps is not null
            union all
            select sk_temps_entree as sk_temps from chu_silver.silver_hospitalisation where sk_temps_entree is not null
            union all
            select sk_temps from chu_silver.silver_satisfaction where sk_temps is not null
            union all
            select sk_temps_deces as sk_temps from chu_silver.silver_deces where sk_temps_deces is not null
        ) u_all
    ) cles_distinctes
) t
where t.date_cal is not null;

-- 2. chargement de dim_region avec membre technique 0
insert overwrite table dim_region
select 0 as sk_region, '00' as code_insee_region, 'INCONNUE' as nom_region
union all
select
    row_number() over (order by code_region) as sk_region,
    code_region as code_insee_region,
    nom_region
from (
    select
        code_region,
        max(nom_region) as nom_region
    from chu_silver.ref_commune_region
    where code_region is not null and code_region <> ''
    group by code_region
) r;

-- 3. chargement de dim_etablissement : exactement 1 ligne par finess_site reel
with cog_unique as (
    select
        code_commune,
        case when count(distinct code_region) = 1 then max(code_region) else cast(null as string) end as code_region
    from chu_silver.ref_commune_region
    group by code_commune
),
etab_par_site as (
    select
        finess_site,
        case when count(distinct identifiant_organisation) = 1 then max(identifiant_organisation) else cast(null as string) end as identifiant_organisation,
        max(finess_etablissement_juridique) as num_finess_ej,
        max(siret_site) as siret_site,
        max(raison_sociale_site) as raison_sociale,
        max(code_postal) as code_postal,
        max(code_commune) as code_commune
    from chu_silver.silver_etablissement
    where finess_site is not null and finess_site <> ''
    group by finess_site
)
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
    row_number() over (order by s.finess_site) as sk_etablissement,
    s.identifiant_organisation,
    s.finess_site as num_finess_site,
    s.num_finess_ej,
    s.siret_site,
    coalesce(s.raison_sociale, 'NON_RENSEIGNE') as raison_sociale,
    s.code_postal,
    s.code_commune,
    coalesce(reg.sk_region, 0) as sk_region
from etab_par_site s
left join cog_unique cog on s.code_commune = cog.code_commune
left join chu_gold.dim_region reg on cog.code_region = reg.code_insee_region and reg.sk_region <> 0;

-- 4. chargement de dim_professionnel : 1 ligne par hash sans duplication par activite
with mode_exercice_unique as (
    select
        id_prof_hash,
        case
            when count(distinct mode_exercice) = 1 then max(mode_exercice)
            else 'MULTIPLE_OU_NR'
        end as mode_exercice
    from chu_silver.silver_bridge_prof_org
    where id_prof_hash is not null
    group by id_prof_hash
),
prof_dedup as (
    select
        id_prof_source_hash,
        max(civilite_exercice) as civilite_exercice,
        max(categorie_pro) as categorie_pro,
        max(profession) as profession,
        max(specialite) as specialite
    from (
        select id_prof_source_hash, civilite_exercice, categorie_pro, profession, specialite
        from chu_silver.silver_professionnel
        where id_prof_source_hash is not null and id_prof_source_hash <> ''
        union all
        select id_prof_source_hash, civilite_exercice, categorie_pro, profession, specialite
        from chu_silver.silver_professionnel_csv
        where id_prof_source_hash is not null and id_prof_source_hash <> ''
    ) p_union
    group by id_prof_source_hash
)
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
    row_number() over (order by p.id_prof_source_hash) as sk_professionnel,
    p.id_prof_source_hash,
    coalesce(p.civilite_exercice, 'NR') as civilite_exercice,
    coalesce(p.categorie_pro, 'NR') as categorie_pro,
    coalesce(p.profession, 'NR') as profession,
    coalesce(p.specialite, 'NR') as specialite,
    coalesce(m.mode_exercice, 'NR') as mode_exercice
from prof_dedup p
left join mode_exercice_unique m on p.id_prof_source_hash = m.id_prof_hash;

-- 5. chargement de dim_patient (avec fallback sur les faits si non encore extrait)
with tous_patients as (
    select
        id_patient_hash,
        max(sexe) as sexe,
        max(tranche_age) as tranche_age
    from (
        select id_patient_hash, sexe, tranche_age from chu_silver.silver_patient where id_patient_hash is not null
        union all
        select distinct id_patient_hash, cast(null as string) as sexe, cast(null as string) as tranche_age from chu_silver.silver_consultation where id_patient_hash is not null
        union all
        select distinct id_patient_hash, cast(null as string) as sexe, cast(null as string) as tranche_age from chu_silver.silver_hospitalisation where id_patient_hash is not null
    ) u
    group by id_patient_hash
)
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
from tous_patients;

-- 6. chargement de dim_diagnostic (avec fallback sur les faits si non encore extrait)
with tous_diagnostics as (
    select
        code_diag,
        max(libelle_diagnostic) as libelle_diagnostic,
        max(categorie_pathologie) as categorie_pathologie
    from (
        select code_diag, libelle_diagnostic, categorie_pathologie from chu_silver.silver_diagnostic where code_diag is not null
        union all
        select distinct code_diag, cast(null as string) as libelle_diagnostic, cast(null as string) as categorie_pathologie from chu_silver.silver_consultation where code_diag is not null
        union all
        select distinct code_diag, cast(null as string) as libelle_diagnostic, cast(null as string) as categorie_pathologie from chu_silver.silver_hospitalisation where code_diag is not null
    ) u
    group by code_diag
)
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
from tous_diagnostics;