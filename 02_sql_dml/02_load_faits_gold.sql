-- activation du partitionnement dynamique et du bucketing sous hive
set hive.exec.dynamic.partition = true;
set hive.exec.dynamic.partition.mode = nonstrict;
set hive.enforce.bucketing = true;

use chu_gold;

-- 1. chargement de fait_consultation (partitionne par annee et buckete par sk_patient)
with pont_etab_unique as (
    -- regle anti duplication : un seul sk_etablissement seulement si organisation et site uniques
    select
        a.id_prof_source_hash,
        case
            when count(distinct e.sk_etablissement) = 1 then max(e.sk_etablissement)
            else 0
        end as sk_etablissement
    from chu_silver.silver_activite_pro a
    left join chu_gold.dim_etablissement e
        on a.identifiant_organisation = e.identifiant_organisation
        and e.sk_etablissement <> 0
    group by a.id_prof_source_hash
)
insert overwrite table fait_consultation partition (annee)
select
    cast(row_number() over (order by c.num_consultation_source) as bigint) as id_fait_consultation,
    c.num_consultation_source,
    cast(date_format(c.date_consultation, 'yyyyMMdd') as int) as sk_temps,
    coalesce(p.sk_patient, cast(0 as bigint)) as sk_patient,
    coalesce(pe.sk_etablissement, 0) as sk_etablissement,
    coalesce(pr.sk_professionnel, 0) as sk_professionnel,
    coalesce(d.sk_diagnostic, 0) as sk_diagnostic,
    1 as nb_consultations,
    case
        when c.duree_consultation_min >= 0 and c.duree_consultation_min <= 720 then c.duree_consultation_min
        else cast(null as decimal(9,2))
    end as duree_consultation_min,
    year(c.date_consultation) as annee
from chu_silver.silver_consultation c
left join chu_gold.dim_patient p
    on c.id_patient_hash = p.id_patient_hash and p.sk_patient <> 0
left join chu_gold.dim_professionnel pr
    on c.id_prof_source_hash = pr.id_prof_source_hash and pr.sk_professionnel <> 0
left join pont_etab_unique pe
    on c.id_prof_source_hash = pe.id_prof_source_hash
left join chu_gold.dim_diagnostic d
    on c.code_diag = d.code_diag and d.sk_diagnostic <> 0
where c.num_consultation_source is not null
  and c.date_consultation is not null;

-- 2. chargement de fait_hospitalisation (partitionne par annee_entree et buckete par sk_patient)
with org_etab_unique as (
    -- affectation du site uniquement si identifiant_organisation pointe vers un seul site finess
    select
        identifiant_organisation,
        case
            when count(distinct sk_etablissement) = 1 then max(sk_etablissement)
            else 0
        end as sk_etablissement
    from chu_gold.dim_etablissement
    where sk_etablissement <> 0
      and identifiant_organisation is not null
    group by identifiant_organisation
)
insert overwrite table fait_hospitalisation partition (annee_entree)
select
    cast(row_number() over (order by h.num_hosp_source) as bigint) as id_fait_hospitalisation,
    h.num_hosp_source,
    cast(date_format(h.date_entree, 'yyyyMMdd') as int) as sk_temps_entree,
    coalesce(p.sk_patient, cast(0 as bigint)) as sk_patient,
    coalesce(oe.sk_etablissement, 0) as sk_etablissement,
    coalesce(d.sk_diagnostic, 0) as sk_diagnostic,
    coalesce(h.suite_consultation, 'NR') as suite_consultation,
    1 as nb_hospitalisations,
    case
        when h.duree_sejour_jours >= 0 and h.duree_sejour_jours <= 365 then h.duree_sejour_jours
        else cast(null as int)
    end as duree_sejour_jours,
    year(h.date_entree) as annee_entree
from chu_silver.silver_hospitalisation h
left join chu_gold.dim_patient p
    on h.id_patient_hash = p.id_patient_hash and p.sk_patient <> 0
left join org_etab_unique oe
    on h.identifiant_organisation = oe.identifiant_organisation
left join chu_gold.dim_diagnostic d
    on h.code_diagnostic = d.code_diag and d.sk_diagnostic <> 0
where h.num_hosp_source is not null
  and h.date_entree is not null;

-- 3. chargement de fait_deces (agregation annuelle par region, sexe et tranche d age)
insert overwrite table fait_deces partition (annee)
select
    cast(row_number() over (order by agg.annee, agg.sk_region, agg.sexe_decede, agg.tranche_age_deces) as bigint) as id_fait_deces,
    cast(concat(cast(agg.annee as string), '1231') as int) as sk_temps_deces,
    agg.sk_region,
    agg.sexe_decede,
    agg.tranche_age_deces,
    agg.nb_deces,
    agg.annee
from (
    select
        year(dec.date_deces) as annee,
        coalesce(reg.sk_region, 0) as sk_region,
        coalesce(dec.sexe, 'INC') as sexe_decede,
        coalesce(dec.tranche_age, 'INC') as tranche_age_deces,
        sum(coalesce(dec.nb_deces, 1)) as nb_deces
    from chu_silver.silver_deces dec
    left join chu_silver.ref_commune_region cog
        on dec.code_lieu_deces = cog.code_commune
    left join chu_gold.dim_region reg
        on cog.code_region = reg.code_insee_region
    where dec.date_deces is not null
    group by
        year(dec.date_deces),
        coalesce(reg.sk_region, 0),
        coalesce(dec.sexe, 'INC'),
        coalesce(dec.tranche_age, 'INC')
) agg;

-- 4. chargement de fait_satisfaction (partitionne par annee_campagne)
insert overwrite table fait_satisfaction partition (annee_campagne)
select
    cast(row_number() over (order by s.annee_campagne, s.finess, s.type_enquete) as bigint) as id_fait_satisfaction,
    cast(concat(cast(s.annee_campagne as string), '1231') as int) as sk_temps,
    coalesce(e.sk_etablissement, 0) as sk_etablissement,
    s.type_enquete,
    case
        when s.score_global_ajuste >= 0 and s.score_global_ajuste <= 100 then s.score_global_ajuste
        else cast(null as decimal(6,2))
    end as score_global_ajuste,
    s.nb_repondants,
    case
        when s.taux_recommandation >= 0 and s.taux_recommandation <= 100 then s.taux_recommandation
        else cast(null as decimal(6,2))
    end as taux_recommandation,
    s.nb_repondants_reco,
    s.annee_campagne
from chu_silver.silver_satisfaction s
left join chu_gold.dim_etablissement e
    on s.finess = e.num_finess_site and e.sk_etablissement <> 0
where s.annee_campagne is not null
  and s.type_enquete in ('ESATIS_48H', 'ESATIS_CA');