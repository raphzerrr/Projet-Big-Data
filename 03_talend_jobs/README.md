# 03_talend_jobs : jobs Talend du projet BIG_DATA

Jobs Talend Open Studio qui extraient, contrôlent et déposent les données sources avant leur chargement dans Hive.

| Job | Source | Fichiers produits |
|---|---|---|
| J1_REFERENTIEL | etablissement_sante.csv | j1_clean, j1_rejets, j1_doublons, j1_qualite |
| J2_PROFESSIONNELS | PostgreSQL (Professionnel_de_sante, Specialites), professionnel_sante.csv, activite_professionnel_sante.csv | j2_clean, j2_rejet, j2_pro_csv_clean, j2_bridge_prof_org, j2_qualite |
| J3_CONSULTATIONS | PostgreSQL (Consultation) | j3_silver, j3_rejets, j3_doublons, j3_qualite |
| J4_HOSPITALISATIONS | Hospitalisations.csv | j4_silver, j4_rejets, j4_doublons, j4_qualite |
| J5_SATISFACTIONS | e-Satis 48 h 2017, 48 h et CA 2019 (CSV), 48 h et CA 2020 (XLSX) | j5_silver, j5_rejets, j5_doublons, j5_qualite |
| J6_DECES | deces.csv, ref_commune_region.csv (COG 2020) | j6_silver (agrégé), j6_rejets, j6_doublons, j6_qualite |
| J7_DEPOT_HDFS | Fichiers clean / silver de J1 à J6 | Dépôt dans /chu/staging/... sur HDFS (Cloudera CDH 5.13) |

Après J7, le chargement Silver puis Gold est lancé par `run_j07_publication.sh` à la racine du dépôt.

## Contenu du dossier

- `BIG_DATA/process/` : les 7 jobs (fichiers `.item`, `.properties`, `.screenshot`).
- `BIG_DATA/code/routines/` : routines Java utilisées par les jobs (`Pseudo` pour le HMAC-SHA256, `J3_Chu` à `J6_Chu` pour les contrôles).
- `BIG_DATA/metadata/` : schémas des fichiers sources et connexion PostgreSQL.
- `BIG_DATA/context/` : groupe de contextes `BDD_PostgreSQL`.
- `captures/` : schéma de chaque job.

## Importer les jobs dans Talend

Dans Talend Open Studio : clic droit sur **Référentiel › Job Designs › Importer des éléments**, choisir le dossier `BIG_DATA`, tout sélectionner, puis **Terminer**.

## Secrets à renseigner avant exécution

Pour ne pas publier de secret sur GitHub, les valeurs suivantes ont été vidées dans les contextes :

- `HMAC_SECRET` (jobs J2, J3, J4) : clé de pseudonymisation des identifiants ;
- `BDD_PostgreSQL_Password` (contexte `BDD_PostgreSQL`, jobs J2 et J3).

Renseignez-les en local dans l'onglet **Contextes** avant de lancer les jobs, sans les committer. Utilisez la même clé HMAC à chaque exécution pour que les identifiants pseudonymisés restent stables.

Les chemins des fichiers d'entrée et de sortie pointent vers le poste qui a développé les jobs (`C:/Users/...`) : adaptez-les à votre machine.
