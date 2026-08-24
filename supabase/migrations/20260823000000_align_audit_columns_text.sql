-- Ces colonnes ont été changées de uuid à text à un moment non documenté
-- avant cet audit, pour stocker person_key (ex. adresse courriel) plutôt
-- qu'un uuid d'utilisateur Supabase Auth. Confirmé sans foreign key active
-- sur ces colonnes (vérifié via pg_constraint). Cette migration aligne le
-- schéma tracké sur ce qui existe réellement en prod.
--
-- Les deux drop constraint qui suivent sont nécessaires pour qu'un rebuild
-- complet depuis zéro fonctionne : 20260818000000_init_stops.sql déclare
-- "updated_by uuid references auth.users(id)" et
-- "modifie_par uuid references auth.users(id)" en ligne, sans nom de
-- contrainte explicite (confirmé par lecture directe du fichier) — Postgres
-- génère alors stops_updated_by_fkey et activity_log_modifie_par_fkey par
-- convention. Sur un rebuild depuis zéro, cette FK serait créée par la
-- migration d'origine puis bloquerait l'ALTER COLUMN ci-dessous si elle
-- n'est pas retirée d'abord. "if exists" : sans effet sur la prod actuelle
-- (la contrainte n'existe déjà plus), nécessaire uniquement pour un rebuild
-- propre.
alter table stops drop constraint if exists stops_updated_by_fkey;
alter table activity_log drop constraint if exists activity_log_modifie_par_fkey;

alter table stops alter column updated_by type text using updated_by::text;
alter table activity_log alter column modifie_par type text using modifie_par::text;
