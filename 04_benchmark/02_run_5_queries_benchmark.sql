-- ============================================================================
-- KIT DE BENCHMARK - ETAPE 2 : EXECUTION DES 5 REQUETES METIER (AVANT vs APRES)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- REQUETE 1 (KPI 7) : Nombre de deces par region sur l annee 2019
-- Test : Impact du Partition Pruning sur l annee 2019 + format Parquet
-- ----------------------------------------------------------------------------

-- [Q1 - AVANT OPTIMISATION] (Full Table Scan en Textfile)
set hive.optimize.ppd = false;
set hive.vectorized.execution.enabled = false;

select
    r.nom_region,
    sum(f.nb_deces) as total_deces_2019
from chu_gold_non_opti.fait_deces_non_opti f
join chu_gold.dim_region r on f.sk_region = r.sk_region
where f.annee = 2019
group by r.nom_region
order by total_deces_2019 desc;

-- [Q1 - APRES OPTIMISATION] (Lecture unique de la partition annee=2019 en Parquet)
set hive.optimize.ppd = true;
set hive.vectorized.execution.enabled = true;

select
    r.nom_region,
    sum(f.nb_deces) as total_deces_2019
from chu_gold.fait_deces f
join chu_gold.dim_region r on f.sk_region = r.sk_region
where f.annee = 2019
group by r.nom_region
order by total_deces_2019 desc;


-- ----------------------------------------------------------------------------
-- REQUETE 2 (KPI 8) : Taux global de satisfaction pondere par region en 2020
-- Test : Impact du partitionnement annee_campagne=2020 et jointure etablissement
-- ----------------------------------------------------------------------------

-- [Q2 - AVANT OPTIMISATION]
set hive.optimize.ppd = false;
set hive.vectorized.execution.enabled = false;

select
    r.nom_region,
    f.type_enquete,
    round(sum(f.score_global_ajuste * f.nb_repondants) / sum(f.nb_repondants), 2) as score_moyen_pondere,
    sum(f.nb_repondants) as total_repondants
from chu_gold_non_opti.fait_satisfaction_non_opti f
join chu_gold.dim_etablissement e on f.sk_etablissement = e.sk_etablissement
join chu_gold.dim_region r on e.sk_region = r.sk_region
where f.annee_campagne = 2020
  and f.score_global_ajuste is not null
  and f.nb_repondants > 0
group by r.nom_region, f.type_enquete
order by f.type_enquete, score_moyen_pondere desc;

-- [Q2 - APRES OPTIMISATION]
set hive.optimize.ppd = true;
set hive.vectorized.execution.enabled = true;

select
    r.nom_region,
    f.type_enquete,
    round(sum(f.score_global_ajuste * f.nb_repondants) / sum(f.nb_repondants), 2) as score_moyen_pondere,
    sum(f.nb_repondants) as total_repondants
from chu_gold.fait_satisfaction f
join chu_gold.dim_etablissement e on f.sk_etablissement = e.sk_etablissement
join chu_gold.dim_region r on e.sk_region = r.sk_region
where f.annee_campagne = 2020
  and f.score_global_ajuste is not null
  and f.nb_repondants > 0
group by r.nom_region, f.type_enquete
order by f.type_enquete, score_moyen_pondere desc;


-- ----------------------------------------------------------------------------
-- REQUETE 3 (KPI 5) : Repartition des hospitalisations par sexe et tranche d age
-- Test : Impact du Bucketing (8 buckets sur sk_patient) + Bucket Map Join
-- ----------------------------------------------------------------------------

-- [Q3 - AVANT OPTIMISATION] (Shuffle Join classique sans buckets)
set hive.auto.convert.join = false;
set hive.optimize.bucketmapjoin = false;

select
    p.sexe,
    p.tranche_age,
    sum(h.nb_hospitalisations) as nb_sejours,
    round(100.0 * sum(h.nb_hospitalisations) / sum(sum(h.nb_hospitalisations)) over (), 2) as part_pct
from chu_gold_non_opti.fait_hospitalisation_non_opti h
join chu_gold_non_opti.dim_patient_non_opti p on h.sk_patient = p.sk_patient
group by p.sexe, p.tranche_age
order by p.sexe, p.tranche_age;

-- [Q3 - APRES OPTIMISATION] (Bucket Map Join active sur sk_patient)
set hive.auto.convert.join = true;
set hive.optimize.bucketmapjoin = true;
set hive.enforce.bucketmapjoin = true;

select
    p.sexe,
    p.tranche_age,
    sum(h.nb_hospitalisations) as nb_sejours,
    round(100.0 * sum(h.nb_hospitalisations) / sum(sum(h.nb_hospitalisations)) over (), 2) as part_pct
from chu_gold.fait_hospitalisation h
join chu_gold.dim_patient p on h.sk_patient = p.sk_patient
group by p.sexe, p.tranche_age
order by p.sexe, p.tranche_age;


-- ----------------------------------------------------------------------------
-- REQUETE 4 (KPI 4) : Hospitalisations et duree moyenne de sejour (DMS) par diagnostic
-- Test : Lecture colonnaire Parquet (seules 3 colonnes lues) + Partition Pruning
-- ----------------------------------------------------------------------------

-- [Q4 - AVANT OPTIMISATION]
set hive.optimize.ppd = false;
set hive.vectorized.execution.enabled = false;

select
    d.categorie_pathologie,
    d.code_diag,
    d.libelle_diagnostic,
    sum(h.nb_hospitalisations) as nb_sejours,
    round(avg(h.duree_sejour_jours), 2) as dms_jours
from chu_gold_non_opti.fait_hospitalisation_non_opti h
join chu_gold.dim_diagnostic d on h.sk_diagnostic = d.sk_diagnostic
where d.sk_diagnostic <> 0
group by d.categorie_pathologie, d.code_diag, d.libelle_diagnostic
order by nb_sejours desc
limit 20;

-- [Q4 - APRES OPTIMISATION]
set hive.optimize.ppd = true;
set hive.vectorized.execution.enabled = true;

select
    d.categorie_pathologie,
    d.code_diag,
    d.libelle_diagnostic,
    sum(h.nb_hospitalisations) as nb_sejours,
    round(avg(h.duree_sejour_jours), 2) as dms_jours
from chu_gold.fait_hospitalisation h
join chu_gold.dim_diagnostic d on h.sk_diagnostic = d.sk_diagnostic
where d.sk_diagnostic <> 0
group by d.categorie_pathologie, d.code_diag, d.libelle_diagnostic
order by nb_sejours desc
limit 20;


-- ----------------------------------------------------------------------------
-- REQUETE 5 (KPI 1 & 6) : Volume et duree moyenne des consultations par specialite et etablissement
-- Test : Jointures multiples en etoile + Vectorisation Parquet + Statistiques CBO
-- ----------------------------------------------------------------------------

-- [Q5 - AVANT OPTIMISATION]
set hive.cbo.enable = false;
set hive.vectorized.execution.enabled = false;

select
    e.raison_sociale,
    pr.specialite,
    sum(c.nb_consultations) as volume_consultations,
    round(avg(c.duree_consultation_min), 2) as duree_moyenne_min
from chu_gold_non_opti.fait_consultation_non_opti c
join chu_gold.dim_etablissement e on c.sk_etablissement = e.sk_etablissement
join chu_gold.dim_professionnel pr on c.sk_professionnel = pr.sk_professionnel
where c.sk_etablissement <> 0
group by e.raison_sociale, pr.specialite
order by volume_consultations desc
limit 25;

-- [Q5 - APRES OPTIMISATION]
set hive.cbo.enable = true;
set hive.vectorized.execution.enabled = true;

select
    e.raison_sociale,
    pr.specialite,
    sum(c.nb_consultations) as volume_consultations,
    round(avg(c.duree_consultation_min), 2) as duree_moyenne_min
from chu_gold.fait_consultation c
join chu_gold.dim_etablissement e on c.sk_etablissement = e.sk_etablissement
join chu_gold.dim_professionnel pr on c.sk_professionnel = pr.sk_professionnel
where c.sk_etablissement <> 0
group by e.raison_sociale, pr.specialite
order by volume_consultations desc
limit 25;