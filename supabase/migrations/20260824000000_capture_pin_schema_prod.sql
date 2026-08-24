-- Cette migration ne fait rien de nouveau en prod : elle documente des objets
-- qui existent déjà (créés manuellement, hors du suivi git de ce repo).
--
-- Niveaux de confiance utilisés ci-dessous :
--   [DÉDUIT AVEC JUSTIFICATION] : colonnes confirmées via information_schema.columns,
--     mais une contrainte (ex. primary key) est déduite du comportement du code
--     (ex. "on conflict (...)") plutôt que vue directement dans pg_constraint.
--   [RECONSTRUCTION PROBABLE, NON CONFIRMÉE] : objet jamais vu en SQL direct
--     (ni dans pg_proc, ni dans pg_policies) ; reconstruit à partir d'indices
--     indirects (colonnes visibles via l'API REST, comportement observé).
--
-- ⚠️ SECTIONS VOLONTAIREMENT ABSENTES DE CETTE MIGRATION :
-- Les fonctions verify_pin, set_user_pin, et la comparaison de log_stop_changes
-- avec la version trackée, ainsi que les 3 policies sur stops (ajout_avec_pin,
-- ecriture_avec_pin, lecture_avec_pin), n'ont pas pu être documentées ici : le
-- texte exact de pg_proc/pg_policies demandé n'a pas été fourni (message reçu
-- avec des espaces réservés non remplis à la place du SQL). À ajouter dans une
-- migration séparée une fois ce contenu réellement fourni.

-- [DÉDUIT AVEC JUSTIFICATION] Colonnes confirmées via information_schema.columns.
-- La contrainte primary key sur person_key n'a pas été vue directement dans
-- pg_constraint : elle est déduite de l'usage "on conflict (person_key)" dans
-- set_user_pin (comportement rapporté, code de la fonction non fourni).
create table if not exists user_pins (
  person_key text not null primary key,
  pin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz default now(),
  nom_affiche text
);

-- [DÉDUIT AVEC JUSTIFICATION] Colonnes confirmées via information_schema.columns.
-- La contrainte primary key sur session_uid n'a pas été vue directement dans
-- pg_constraint : elle est déduite de l'usage "on conflict (session_uid)" dans
-- verify_pin (comportement rapporté, code de la fonction non fourni).
create table if not exists pin_unlocks (
  session_uid uuid not null primary key,
  person_key text not null,
  unlocked_until timestamptz not null
);

-- [RECONSTRUCTION PROBABLE, NON CONFIRMÉE] Cette vue n'a jamais été vue en SQL
-- direct (ni pg_proc ni pg_policies ne la couvrent). Reconstruite à partir des
-- deux seules colonnes confirmées visibles via l'API REST (person_key,
-- nom_affiche) sur un endpoint nommé user_pins_public. La définition réelle
-- (nom de la vue, security_invoker, filtre éventuel) n'est pas confirmée.
create or replace view user_pins_public as
  select person_key, nom_affiche from user_pins;
