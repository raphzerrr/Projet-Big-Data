-- ============================================================================
-- AUDIT DE QUALITE, CONTROLES D INTEGRITE ET EXPORTS J07
-- ============================================================================

set hiveconf:run_id = RUN_J07_2026;
use chu_control;

-- 1. alimentation de journal_qualite (idempotent : ecrase le meme id_run si relance)
insert overwrite table journal_qualite
select * from journal_qualite where id_run <> '${hiveconf:run_id}'
union all
select
    '${hiveconf:run_id}' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_CONSULTATION' as nom_table,
    'duree_consultation_min / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(duree_consultation_min) / nullif(count(*), 0), 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct num_consultation_source) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_consultation
union all
select
    '${hiveconf:run_id}' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_HOSPITALISATION' as nom_table,
    'duree_sejour_jours / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(duree_sejour_jours) / nullif(count(*), 0), 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct num_hosp_source) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_hospitalisation
union all
select
    '${hiveconf:run_id}' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_SATISFACTION' as nom_table,
    'score_global_ajuste / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(score_global_ajuste) / nullif(count(*), 0), 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct concat(cast(annee_campagne as string), '_', cast(sk_etablissement as string), '_', type_enquete)) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_satisfaction
union all
select
    '${hiveconf:run_id}' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_DECES' as nom_table,
    'nb_deces (cible=24782307) / sk_region' as nom_attribut,
    cast(round(100.0 * sum(nb_deces) / 24782307.0, 2) as decimal(5,2)) as taux_completude,
    cast(0 as bigint) as nb_doublons,
    cast(sum(case when sk_region = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_deces;


-- 2. journalisation des lots j07 dans journal_lots
insert overwrite table journal_lots
select * from journal_lots where id_run <> '${hiveconf:run_id}'
union all
select
    '${hiveconf:run_id}' as id_run,
    'J07_GOLD_PUBLICATION' as nom_job,
    'CHU_SILVER_PARQUET' as source_donnees,
    sha2(concat('${hiveconf:run_id}', '_CHU_GOLD'), 256) as empreinte_sha256,
    current_timestamp() as date_debut,
    current_timestamp() as date_fin,
    (select count(*) from chu_silver.silver_consultation)
      + (select count(*) from chu_silver.silver_hospitalisation)
      + (select count(*) from chu_silver.silver_satisfaction)
      + (select count(*) from chu_silver.silver_deces) as nb_lignes_lues,
    (select count(*) from chu_gold.fait_consultation)
      + (select count(*) from chu_gold.fait_hospitalisation)
      + (select count(*) from chu_gold.fait_satisfaction)
      + (select count(*) from chu_gold.fait_deces) as nb_lignes_chargees,
    (select count(*) from chu_control.quarantaine_satisfaction where id_run = '${hiveconf:run_id}') as nb_lignes_rejetees,
    'SUCCESS' as statut;


-- 3. generation des fichiers csv d export j07 (/tmp/j7_exports/)
insert overwrite local directory '/tmp/j7_exports/j7_tables_counts'
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
union all select 'QUARANTAINE_SATISFACTION', count(*) from chu_control.quarantaine_satisfaction;

insert overwrite local directory '/tmp/j7_exports/j7_integrite'
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

insert overwrite local directory '/tmp/j7_exports/j7_publication_lots'
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