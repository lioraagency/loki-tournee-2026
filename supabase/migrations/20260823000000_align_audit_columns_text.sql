-- Ces colonnes ont été changées de uuid à text à un moment non documenté
-- avant cet audit, pour stocker person_key (ex. adresse courriel) plutôt
-- qu'un uuid d'utilisateur Supabase Auth. Confirmé sans foreign key active
-- sur ces colonnes (vérifié via pg_constraint). Cette migration aligne le
-- schéma tracké sur ce qui existe réellement en prod.
alter table stops alter column updated_by type text using updated_by::text;
alter table activity_log alter column modifie_par type text using modifie_par::text;
