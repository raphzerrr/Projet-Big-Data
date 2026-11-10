-- ============================================================================
-- AUDIT DE QUALITE, CONTROLES D INTEGRITE ET EXPORTS J05 / J07 (HIVE 1.1)
-- ============================================================================

use chu_control;

-- 1. alimentation idempotente de journal_qualite (sans current_timestamp ni auto-lecture)
drop table if exists stg_journal_qualite;
create table stg_journal_qualite stored as parquet as
select * from journal_qualite where id_run <> '${hiveconf:run_id}'
union all
select
    '${hiveconf:run_id}' as id_run,
    cast(from_unixtime(unix_timestamp()) as timestamp) as date_mesure,
    'FAIT_CONSULTATION' as nom_table,
    'duree_consultation_min / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(duree_consultation_min) / case when count(*) = 0 then cast(null as bigint) else count(*) end, 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct num_consultation_source) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_consultation
union all
select
    '${hiveconf:run_id}' as id_run,
    cast(from_unixtime(unix_timestamp()) as timestamp) as date_mesure,
    'FAIT_HOSPITALISATION' as nom_table,
    'duree_sejour_jours / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(duree_sejour_jours) / case when count(*) = 0 then cast(null as bigint) else count(*) end, 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct num_hosp_source) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_hospitalisation
union all
select
    '${hiveconf:run_id}' as id_run,
    cast(from_unixtime(unix_timestamp()) as timestamp) as date_mesure,
    'FAIT_SATISFACTION' as nom_table,
    'score_global_ajuste / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(score_global_ajuste) / case when count(*) = 0 then cast(null as bigint) else count(*) end, 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct concat(cast(annee_campagne as string), '_', cast(sk_etablissement as string), '_', type_enquete)) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_satisfaction
union all
select
    '${hiveconf:run_id}' as id_run,
    cast(from_unixtime(unix_timestamp()) as timestamp) as date_mesure,
    'FAIT_DECES' as nom_table,
    'nb_deces (cible=24782307) / sk_region' as nom_attribut,
    cast(round(100.0 * sum(nb_deces) / 24782307.0, 2) as decimal(5,2)) as taux_completude,
    cast(0 as bigint) as nb_doublons,
    cast(sum(case when sk_region = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_deces;

insert overwrite table journal_qualite
select * from stg_journal_qualite;
drop table if exists stg_journal_qualite;


-- 2. alimentation idempotente de journal_lots avec vrai sha-256 compatible hive 1.1 via reflect(DigestUtils)
drop table if exists stg_journal_lots;
create table stg_journal_lots stored as parquet as
select * from journal_lots where id_run <> '${hiveconf:run_id}'
union all
select
    '${hiveconf:run_id}' as id_run,
    'J07_GOLD_PUBLICATION' as nom_job,
    'CHU_SILVER_PARQUET' as source_donnees,
    reflect('org.apache.commons.codec.digest.DigestUtils', 'sha256Hex',
        concat_ws('|',
            cast(m.cnt_consult as string),
            cast(m.sum_consult_min as string),
            cast(m.cnt_hosp as string),
            cast(m.sum_hosp_jours as string),
            cast(m.cnt_sat as string),
            cast(m.sum_sat_rep as string),
            cast(m.cnt_deces as string),
            cast(m.sum_nb_deces as string),
            cast(m.cnt_quarantaine as string)
        )
    ) as empreinte_sha256,
    cast(from_unixtime(unix_timestamp()) as timestamp) as date_debut,
    cast(from_unixtime(unix_timestamp()) as timestamp) as date_fin,
    m.lignes_lues as nb_lignes_lues,
    (m.cnt_consult + m.cnt_hosp + m.cnt_sat + m.cnt_deces) as nb_lignes_chargees,
    m.cnt_quarantaine as nb_lignes_rejetees,
    case when m.sum_nb_deces = 24782307 and m.cles_quarantaine = 72 and m.cnt_quarantaine = 211 then 'SUCCESS' else 'WARN_CHECK_METRICS' end as statut
from (
    select
        (select count(*) from chu_silver.silver_consultation)
          + (select count(*) from chu_silver.silver_hospitalisation)
          + (select count(*) from chu_silver.silver_satisfaction)
          + (select count(*) from chu_silver.silver_deces) as lignes_lues,
        (select count(*) from chu_gold.fait_consultation) as cnt_consult,
        (select coalesce(sum(duree_consultation_min), cast(0 as decimal(9,2))) from chu_gold.fait_consultation) as sum_consult_min,
        (select count(*) from chu_gold.fait_hospitalisation) as cnt_hosp,
        (select coalesce(sum(duree_sejour_jours), 0) from chu_gold.fait_hospitalisation) as sum_hosp_jours,
        (select count(*) from chu_gold.fait_satisfaction) as cnt_sat,
        (select coalesce(sum(nb_repondants), 0) from chu_gold.fait_satisfaction) as sum_sat_rep,
        (select count(*) from chu_gold.fait_deces) as cnt_deces,
        (select coalesce(sum(nb_deces), 0) from chu_gold.fait_deces) as sum_nb_deces,
        (select count(*) from chu_control.quarantaine_satisfaction where id_run = '${hiveconf:run_id}') as cnt_quarantaine,
        (select count(distinct concat(cast(annee_campagne as string), '_', type_enquete, '_', cle_rattachement)) from chu_control.quarantaine_satisfaction where id_run = '${hiveconf:run_id}') as cles_quarantaine
) m;

insert overwrite table journal_lots
select * from stg_journal_lots;
drop table if exists stg_journal_lots;


-- 3. exports j07 (comptages, integrite, lots) et exports j05 (arbitrages et rattachements finess)
insert overwrite local directory '/tmp/j7_raw/tables_counts'
row format delimited fields terminated by ';'
select 'DIM_TEMPS', count(*) from chu_gold.dim_temps
union all select 'DIM_REGION', count(*) from chu_gold.dim_region
union all select 'DIM_ETABLISSEMENT', count(*) from chu_gold.dim_etablissement
union all select 'DIM_PATIENT', count(*) from chu_gold.dim_patient
union all select 'DIM_DIAGNOSTIC', count(*) from chu_gold.dim_diagnostic
union all select 'DIM_PROFESSIONNEL', count(*) from chu_gold.dim_professionnel
union all select 'FAIT_CONSULTATION', count(*) from chu_gold.fait_consultation
union all select 'FAIT_HOSPITALISATION', count(*) from chu_gold.fait_hospitalisation
union all select 'FAIT_SATISFACTION', count(*) from chu_gold.fait_satisfaction
union all select 'FAIT_DECES_LIGNES', count(*) from chu_gold.fait_deces
union all select 'FAIT_DECES_VOLUME_TOTAL', sum(nb_deces) from chu_gold.fait_deces
union all select 'QUARANTAINE_SATISFACTION_LIGNES', count(*) from chu_control.quarantaine_satisfaction
union all select 'QUARANTAINE_SATISFACTION_CLES', count(distinct concat(cast(annee_campagne as string), '_', type_enquete, '_', cle_rattachement)) from chu_control.quarantaine_satisfaction;

insert overwrite local directory '/tmp/j7_raw/integrite'
row format delimited fields terminated by ';'
select
    id_run,
    nom_table,
    nom_attribut,
    taux_completude,
    nb_doublons,
    nb_orphelins_fk
from chu_control.journal_qualite
where id_run = '${hiveconf:run_id}';

insert overwrite local directory '/tmp/j7_raw/publication_lots'
row format delimited fields terminated by ';'
select
    id_run,
    nom_job,
    source_donnees,
    empreinte_sha256,
    date_debut,
    date_fin,
    nb_lignes_lues,
    nb_lignes_chargees,
    nb_lignes_rejetees,
    statut
from chu_control.journal_lots
where id_run = '${hiveconf:run_id}';

-- export j5_arbitrages_gold : detail des 72 cles amigues (211 observations) mises en quarantaine
insert overwrite local directory '/tmp/j7_raw/j5_arbitrages_gold'
row format delimited fields terminated by ';'
select
    id_run,
    fichier_source,
    annee_campagne,
    type_enquete,
    finess_geo,
    finess,
    cle_rattachement,
    score_global_ajuste,
    nb_repondants,
    motif_quarantaine
from chu_control.quarantaine_satisfaction
where id_run = '${hiveconf:run_id}'
order by annee_campagne, type_enquete, cle_rattachement;

-- export j5_rattachement_gold : bilan du rattachement finess vers dim_etablissement des enquetes publiees
insert overwrite local directory '/tmp/j7_raw/j5_rattachement_gold'
row format delimited fields terminated by ';'
select
    s.annee_campagne,
    s.type_enquete,
    case
        when s.sk_etablissement <> 0 then 'RATTACHE_SITE_UNIVOQUE'
        else 'NON_RATTACHE_INCONNU_0'
    end as statut_rattachement,
    count(*) as nb_enquetes_publiees
from chu_gold.fait_satisfaction s
group by
    s.annee_campagne,
    s.type_enquete,
    case
        when s.sk_etablissement <> 0 then 'RATTACHE_SITE_UNIVOQUE'
        else 'NON_RATTACHE_INCONNU_0'
    end
order by s.annee_campagne, s.type_enquete, statut_rattachement;