-- activation du partitionnement dynamique et du bucketing
set hive.exec.dynamic.partition = true;
set hive.exec.dynamic.partition.mode = nonstrict;
set hive.enforce.bucketing = true;
set hiveconf:run_id = RUN_J07_GOLD;

use chu_gold;

-- 1. chargement de fait_consultation (j03)
with org_univoque_site as (
    select
        identifiant_organisation,
        case
            when count(*) = 1 and count(distinct finess_site) = 1 then max(finess_site)
            else cast(null as string)
        end as finess_site_unique
    from chu_silver.silver_etablissement
    where identifiant_organisation is not null
    group by identifiant_organisation
),
prof_univoque_etab as (
    select
        b.id_prof_hash,
        case
            when max(b.nb_organisations) = 1
             and count(distinct b.identifiant_organisation) = 1
             and count(distinct e.sk_etablissement) = 1
            then max(e.sk_etablissement)
            else 0
        end as sk_etablissement
    from chu_silver.silver_bridge_prof_org b
    left join org_univoque_site o on b.identifiant_organisation = o.identifiant_organisation
    left join chu_gold.dim_etablissement e on o.finess_site_unique = e.num_finess_site and e.sk_etablissement <> 0
    group by b.id_prof_hash
),
consult_dedup as (
    select
        *,
        row_number() over (partition by num_consultation_source order by sk_temps desc) as rn
    from chu_silver.silver_consultation
    where num_consultation_source is not null and sk_temps is not null
)
insert overwrite table fait_consultation partition (annee)
select
    cast(row_number() over (order by c.num_consultation_source) as bigint) as id_fait_consultation,
    c.num_consultation_source,
    coalesce(t.sk_temps, 0) as sk_temps,
    coalesce(p.sk_patient, cast(0 as bigint)) as sk_patient,
    coalesce(pe.sk_etablissement, 0) as sk_etablissement,
    coalesce(pr.sk_professionnel, 0) as sk_professionnel,
    coalesce(d.sk_diagnostic, 0) as sk_diagnostic,
    coalesce(c.nb_consultations, 1) as nb_consultations,
    case
        when c.duree_consultation_min >= 0 and c.duree_consultation_min <= 720 then c.duree_consultation_min
        else cast(null as decimal(9,2))
    end as duree_consultation_min,
    cast(c.sk_temps / 10000 as int) as annee
from consult_dedup c
left join chu_gold.dim_temps t on c.sk_temps = t.sk_temps and t.sk_temps <> 0
left join chu_gold.dim_patient p on c.id_patient_hash = p.id_patient_hash and p.sk_patient <> 0
left join chu_gold.dim_professionnel pr on c.id_prof_source_hash = pr.id_prof_source_hash and pr.sk_professionnel <> 0
left join prof_univoque_etab pe on c.id_prof_source_hash = pe.id_prof_hash
left join chu_gold.dim_diagnostic d on c.code_diag = d.code_diag and d.sk_diagnostic <> 0
where c.rn = 1;


-- 2. chargement de fait_hospitalisation (j04)
with org_univoque_etab as (
    select
        s.identifiant_organisation,
        case
            when count(*) = 1 and count(distinct e.sk_etablissement) = 1 then max(e.sk_etablissement)
            else 0
        end as sk_etablissement
    from chu_silver.silver_etablissement s
    left join chu_gold.dim_etablissement e on s.finess_site = e.num_finess_site and e.sk_etablissement <> 0
    where s.identifiant_organisation is not null
    group by s.identifiant_organisation
),
hosp_dedup as (
    select
        *,
        row_number() over (partition by num_hosp_source order by sk_temps_entree desc) as rn
    from chu_silver.silver_hospitalisation
    where num_hosp_source is not null and sk_temps_entree is not null
)
insert overwrite table fait_hospitalisation partition (annee_entree)
select
    cast(row_number() over (order by h.num_hosp_source) as bigint) as id_fait_hospitalisation,
    h.num_hosp_source,
    coalesce(t.sk_temps, 0) as sk_temps_entree,
    coalesce(p.sk_patient, cast(0 as bigint)) as sk_patient,
    coalesce(oe.sk_etablissement, 0) as sk_etablissement,
    coalesce(d.sk_diagnostic, 0) as sk_diagnostic,
    coalesce(h.suite_consultation, 'NR') as suite_consultation,
    coalesce(h.nb_hospitalisations, 1) as nb_hospitalisations,
    case
        when h.duree_sejour_jours >= 0 and h.duree_sejour_jours <= 365 then h.duree_sejour_jours
        else cast(null as int)
    end as duree_sejour_jours,
    cast(h.sk_temps_entree / 10000 as int) as annee_entree
from hosp_dedup h
left join chu_gold.dim_temps t on h.sk_temps_entree = t.sk_temps and t.sk_temps <> 0
left join chu_gold.dim_patient p on h.id_patient_hash = p.id_patient_hash and p.sk_patient <> 0
left join org_univoque_etab oe on h.identifiant_organisation = oe.identifiant_organisation
left join chu_gold.dim_diagnostic d on h.code_diag = d.code_diag and d.sk_diagnostic <> 0
where h.rn = 1;


-- 3. chargement de fait_deces (j06 : 20 545 lignes deja agregees, total 24 782 307 deces)
insert overwrite table fait_deces partition (annee)
select
    cast(row_number() over (order by dec.sk_temps_deces, dec.code_region, dec.sexe_decede, dec.tranche_age_deces) as bigint) as id_fait_deces,
    coalesce(t.sk_temps, dec.sk_temps_deces) as sk_temps_deces,
    coalesce(reg.sk_region, 0) as sk_region,
    coalesce(dec.sexe_decede, 'INC') as sexe_decede,
    coalesce(dec.tranche_age_deces, 'INC') as tranche_age_deces,
    dec.nb_deces,
    cast(dec.sk_temps_deces / 10000 as int) as annee
from chu_silver.silver_deces dec
left join chu_gold.dim_temps t on dec.sk_temps_deces = t.sk_temps and t.sk_temps <> 0
left join chu_gold.dim_region reg on dec.code_region = reg.code_insee_region and reg.sk_region <> 0
where dec.sk_temps_deces is not null;


-- 4. quarantaine et chargement de fait_satisfaction (j05)
-- 4a. mise en quarantaine stricte des 72 cles gold amigues (211 observations) sur (annee_campagne, type_enquete, cle_rattachement)
with cles_ambigues as (
    select
        annee_campagne,
        type_enquete,
        cle_rattachement
    from chu_silver.silver_satisfaction
    where annee_campagne is not null
      and type_enquete in ('ESATIS_48H', 'ESATIS_CA')
      and cle_rattachement is not null
    group by annee_campagne, type_enquete, cle_rattachement
    having count(*) > 1
)
insert overwrite table chu_control.quarantaine_satisfaction
select
    '${hiveconf:run_id}' as id_run,
    s.fichier_source,
    s.annee_campagne,
    s.type_enquete,
    s.finess_geo,
    s.finess,
    s.cle_rattachement,
    s.score_global_ajuste,
    s.nb_repondants,
    'ERR_DUP_GOLD_KEY_AMBIGUOUS_72_KEYS' as motif_quarantaine
from chu_silver.silver_satisfaction s
join cles_ambigues a
  on s.annee_campagne = a.annee_campagne
 and s.type_enquete = a.type_enquete
 and s.cle_rattachement = a.cle_rattachement;

-- 4b. chargement dans fait_satisfaction des observations univoques sans rattachement finess_ej arbitraire
-- regle : priorite a finess_geo = num_finess_site ; si finess_geo absent, finess = num_finess_site ; sinon sk_etablissement = 0
with cles_univoques as (
    select
        annee_campagne,
        type_enquete,
        cle_rattachement
    from chu_silver.silver_satisfaction
    where annee_campagne is not null
      and type_enquete in ('ESATIS_48H', 'ESATIS_CA')
      and cle_rattachement is not null
    group by annee_campagne, type_enquete, cle_rattachement
    having count(*) = 1
)
insert overwrite table fait_satisfaction partition (annee_campagne)
select
    cast(row_number() over (order by s.annee_campagne, s.cle_rattachement, s.type_enquete) as bigint) as id_fait_satisfaction,
    coalesce(t.sk_temps, s.sk_temps, cast(concat(cast(s.annee_campagne as string), '1231') as int)) as sk_temps,
    case
        when s.finess_geo is not null and e_geo.sk_etablissement is not null then e_geo.sk_etablissement
        when s.finess_geo is null and e_site.sk_etablissement is not null then e_site.sk_etablissement
        else 0
    end as sk_etablissement,
    s.type_enquete,
    case when s.score_global_ajuste >= 0 and s.score_global_ajuste <= 100 then s.score_global_ajuste else cast(null as decimal(6,2)) end as score_global_ajuste,
    s.nb_repondants,
    case when s.taux_recommandation >= 0 and s.taux_recommandation <= 100 then s.taux_recommandation else cast(null as decimal(6,2)) end as taux_recommandation,
    s.nb_repondants_reco,
    s.annee_campagne
from chu_silver.silver_satisfaction s
join cles_univoques u
  on s.annee_campagne = u.annee_campagne
 and s.type_enquete = u.type_enquete
 and s.cle_rattachement = u.cle_rattachement
left join chu_gold.dim_temps t on s.sk_temps = t.sk_temps and t.sk_temps <> 0
left join chu_gold.dim_etablissement e_geo on s.finess_geo = e_geo.num_finess_site and e_geo.sk_etablissement <> 0
left join chu_gold.dim_etablissement e_site on s.finess = e_site.num_finess_site and e_site.sk_etablissement <> 0
where s.annee_campagne is not null;