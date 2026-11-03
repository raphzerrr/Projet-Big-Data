📌 Présentation du ProjetCe dépôt contient l'ensemble des scripts d'implémentation physique (DDL/DML Apache Hive), les flux d'intégration (Talend), le protocole de benchmark de performance et les audits de qualité de données de la plateforme Cloud Healthcare Unit (CHU).L'architecture repose sur un Lakehouse Cloudera (HDFS / Apache Hive) structuré selon le paradigme Médaillon (Bronze / Silver / Gold) et modélisé en constellation de Kimball (6 dimensions conformes et 4 tables de faits) afin de répondre aux exigences de volumétrie (3V), de gouvernance RGPD (pseudonymisation HMAC-SHA-256, minimisation) et de conformité HDS.📂 Structure du Dépôt📁 Projet-CHU-Data
├── 📁 01_sql_ddl                        # Scripts de définition des schémas (Data Definition Language)
│   ├── 01_create_silver.sql             # Création de la base chu_silver (Parquet, tables nettoyées & ponts)
│   ├── 02_create_gold.sql               # Création de la base chu_gold (Constellation, Partitionnement & Bucketing)
│   └── 03_create_control.sql            # Création de la base chu_control (Journaux d'audit, lots et rejets)
│
├── 📁 02_sql_dml                        # Scripts de chargement et transformation (Data Manipulation Language)
│   ├── 01_load_dimensions_gold.sql      # Initialisation des membres '0' (INCONNU) et chargement des 6 dimensions
│   ├── 02_load_faits_gold.sql           # Alimentation dynamique des partitions/buckets et règles anti-duplication
│   └── 03_data_quality_audit.sql        # Calcul de complétude, doublons et cohérence référentielle (FINESS/COG)
│
├── 📁 03_talend_jobs                    # Exports (.zip) des jobs Talend d'ingestion et de nettoyage (J01 à J07)
│
├── 📁 04_benchmark                      # Protocole d'évaluation des performances (Avant / Après optimisation)
│   ├── 01_setup_benchmark_env.sql       # Création de la base témoin non optimisée (TEXTFILE) + Statistiques CBO
│   └── 02_run_5_queries_benchmark.sql   # Exécution comparative des 5 requêtes décisionnelles métier
│
├── 📁 05_rapports                       # Documentation livrable, rapport de qualité et graphiques de performance
│
├── .gitignore                           # Exclusion stricte des données brutes/massives (.csv, .xlsx, .parquet)
└── README.md                            # Documentation générale du dépôt
⚙️ Choix Techniques & Optimisations Physiques (Couche Gold)Format de stockage colonnaire : Utilisation d'Apache Parquet sur les couches chu_silver et chu_gold pour réduire l'empreinte disque et ne lire que les colonnes projetées lors des agrégations analytiques.Partitionnement physique (PARTITIONED BY) :fait_consultation : partitionné par anneefait_hospitalisation : partitionné par annee_entreefait_deces : partitionné par anneefait_satisfaction : partitionné par annee_campagneObjectif : Activer le Partition Pruning lors du calcul des indicateurs annuels (ex. Décès 2019, Satisfaction 2020) afin d'éviter les parcours complets (Full Table Scans).Bucketing (CLUSTERED BY ... INTO 8 BUCKETS) :Appliqué sur la clé sk_patient pour dim_patient, fait_consultation et fait_hospitalisation.Objectif : Optimiser les jointures volumineuses entre les événements médicaux et les patients via l'activation du Bucket Map Join.Intégrité référentielle logique :Insertion systématique d'un enregistrement technique sk_* = 0 (INCONNU) dans chaque table de dimension.Résolution par COALESCE(dim.sk_*, 0) et arbitrage univoque des établissements (COUNT(DISTINCT sk_etablissement) = 1) pour interdire toute valeur NULL sur clé étrangère et toute multiplication artificielle des faits.🚀 Ordre d'Exécution des Scripts (Déploiement sur Cloudera VM)Les scripts SQL s'exécutent via Beeline (ou l'interface Hue) dans l'ordre chronologique suivant :Étape 1 — Initialisation des schémas (DDL)beeline -u jdbc:hive2://localhost:10000 -f 01_sql_ddl/01_create_silver.sql
beeline -u jdbc:hive2://localhost:10000 -f 01_sql_ddl/02_create_gold.sql
beeline -u jdbc:hive2://localhost:10000 -f 01_sql_ddl/03_create_control.sql
Étape 2 — Exécution des Jobs Talend (Bronze $\rightarrow$ Silver)Importer et exécuter les jobs du dossier 03_talend_jobs/ (J01 à J06) afin d'alimenter les tables de la base chu_silver à partir des fichiers sources (PostgreSQL DATA2023, CSV référentiels, hospitalisation.csv, deces.csv, fichiers e-Satis).Étape 3 — Alimentation de l'entrepôt Gold & Audit Qualité (DML)beeline -u jdbc:hive2://localhost:10000 -f 02_sql_dml/01_load_dimensions_gold.sql
beeline -u jdbc:hive2://localhost:10000 -f 02_sql_dml/02_load_faits_gold.sql
beeline -u jdbc:hive2://localhost:10000 -f 02_sql_dml/03_data_quality_audit.sql
Étape 4 — Exécution du Benchmark (Avant / Après)beeline -u jdbc:hive2://localhost:10000 -f 04_benchmark/01_setup_benchmark_env.sql
beeline -u jdbc:hive2://localhost:10000 -f 04_benchmark/02_run_5_queries_benchmark.sql
🛡️ Règles de Collaboration Git & Sécurité RGPDAucune donnée dans Git : Il est strictement interdit de commiter des fichiers de données sources ou générés (.csv, .xlsx, .parquet, dumps .sql contenant des enregistrements). Le fichier .gitignore filtre ces extensions par défaut.Protection des données personnelles : Aucune donnée directement identifiante (nom, prenom, adresse, NIR, numero_acte_deces) ne doit transiter dans les schémas chu_silver et chu_gold.Convention de nommage des commits :feat(ddl): ... pour les créations ou modifications de structures SQLfeat(dml): ... pour les scripts d'alimentation et de contrôle qualitéfeat(talend): ... pour l'ajout d'archives de jobs Talenddocs(rapport): ... pour la documentation et l'analyse du benchmark
