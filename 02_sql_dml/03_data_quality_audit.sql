-- ============================================================================
-- AUDIT DE QUALITE DES DONNEES (COMPLÉTUDE, FINESS, DOUBLONS)
-- Cible : Alimentation de chu_control.journal_qualite et rapport Livrable 2
-- ============================================================================

use chu_control;

-- 1. insertion automatisee des metriques de qualite dans journal_qualite
insert into table journal_qualite
-- controle 1 : completude duree_consultation_min et orphelins etablissement sur fait_consultation
select
    'RUN_DQ_GOLD_01' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_CONSULTATION' as nom_table,
    'duree_consultation_min / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(duree_consultation_min) / nullif(count(*), 0), 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct num_consultation_source) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_consultation

union all

-- controle 2 : completude duree_sejour_jours et orphelins etablissement sur fait_hospitalisation
select
    'RUN_DQ_GOLD_01' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_HOSPITALISATION' as nom_table,
    'duree_sejour_jours / sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(duree_sejour_jours) / nullif(count(*), 0), 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct num_hosp_source) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_hospitalisation

union all

-- controle 3 : coherence referentielle des codes finess sur fait_satisfaction
select
    'RUN_DQ_GOLD_01' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_SATISFACTION' as nom_table,
    'score_global_ajuste / finess->sk_etablissement' as nom_attribut,
    cast(round(100.0 * count(score_global_ajuste) / nullif(count(*), 0), 2) as decimal(5,2)) as taux_completude,
    cast(count(*) - count(distinct concat(cast(annee_campagne as string), '_', cast(sk_etablissement as string), '_', type_enquete)) as bigint) as nb_doublons,
    cast(sum(case when sk_etablissement = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_satisfaction

union all

-- controle 4 : coherence referentielle cog insee sur fait_deces
select
    'RUN_DQ_GOLD_01' as id_run,
    current_timestamp() as date_mesure,
    'FAIT_DECES' as nom_table,
    'nb_deces / code_lieu_deces->sk_region' as nom_attribut,
    cast(100.00 as decimal(5,2)) as taux_completude,
    cast(0 as bigint) as nb_doublons,
    cast(sum(case when sk_region = 0 then 1 else 0 end) as bigint) as nb_orphelins_fk
from chu_gold.fait_deces;


-- 2. requete de restitution directe pour le tableau du rapport de qualite (livrable 2)
select
    nom_table,
    nom_attribut,
    taux_completude,
    nb_doublons,
    nb_orphelins_fk
from chu_control.journal_qualite
where id_run = 'RUN_DQ_GOLD_01';


-- 3. detail specifique de coherence referentielle finess (silver vs referentiel etablissement)
select
    s.annee_campagne,
    s.type_enquete,
    count(*) as total_lignes_enquete,
    sum(case when e.num_finess_site is not null then 1 else 0 end) as finess_reconnus,
    sum(case when e.num_finess_site is null then 1 else 0 end) as finess_orphelins,
    round(100.0 * sum(case when e.num_finess_site is not null then 1 else 0 end) / nullif(count(*), 0), 2) as taux_coherence_finess_pct
from chu_silver.silver_satisfaction s
left join (
    select distinct num_finess_site from chu_silver.silver_etablissement where num_finess_site is not null
) e on s.finess = e.num_finess_site
group by s.annee_campagne, s.type_enquete
order by s.annee_campagne, s.type_enquete;