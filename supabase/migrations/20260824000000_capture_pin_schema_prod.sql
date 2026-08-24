-- Cette migration ne fait rien de nouveau en prod : elle documente des objets
-- qui existent déjà (créés manuellement, hors du suivi git de ce repo).
--
-- Niveaux de confiance utilisés ci-dessous :
--   [CONFIRMÉ VERBATIM] : texte exact vu directement dans pg_proc / pg_policies
--     en prod, collé tel quel.
--   [DÉDUIT AVEC JUSTIFICATION] : colonnes confirmées via information_schema.columns,
--     mais une contrainte (ex. primary key) est déduite du comportement du code
--     (ex. "on conflict (...)") plutôt que vue directement dans pg_constraint.
--   [RECONSTRUCTION PROBABLE, NON CONFIRMÉE] : objet jamais vu en SQL direct
--     (ni dans pg_proc, ni dans pg_policies) ; reconstruit à partir d'indices
--     indirects (colonnes visibles via l'API REST, comportement observé).

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

-- [CONFIRMÉ VERBATIM] Vu directement dans pg_proc en prod.
CREATE OR REPLACE FUNCTION public.verify_pin(p_person_key text, p_pin text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  rec user_pins%rowtype;
  ok boolean;
begin
  if auth.uid() is null then
    raise exception 'Session invalide, recharge la page.';
  end if;
  select * into rec from user_pins where person_key = lower(p_person_key);
  if not found then
    return false;
  end if;
  if rec.locked_until is not null and rec.locked_until > now() then
    raise exception 'Compte temporairement verrouillé, réessaie plus tard.';
  end if;
  ok := (rec.pin_hash = crypt(p_pin, rec.pin_hash));
  if ok then
    update user_pins set failed_attempts = 0, locked_until = null where person_key = lower(p_person_key);
    insert into pin_unlocks(session_uid, person_key, unlocked_until)
    values (auth.uid(), lower(p_person_key), now() + interval '8 hours')
    on conflict (session_uid) do update
      set person_key = excluded.person_key, unlocked_until = excluded.unlocked_until;
    return true;
  else
    update user_pins
      set failed_attempts = failed_attempts + 1,
          locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
      where person_key = lower(p_person_key);
    return false;
  end if;
end;
$function$;

-- [CONFIRMÉ VERBATIM] Vu directement dans pg_proc en prod.
CREATE OR REPLACE FUNCTION public.set_user_pin(p_person_key text, p_pin text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if p_pin !~ '^[0-9]{4}$' then
    raise exception 'Le PIN doit être exactement 4 chiffres';
  end if;
  insert into user_pins(person_key, pin_hash, failed_attempts, locked_until)
  values (lower(p_person_key), crypt(p_pin, gen_salt('bf')), 0, null)
  on conflict (person_key) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();
end;
$function$;

-- [CONFIRMÉ VERBATIM] Vu directement dans pg_proc en prod.
-- Comparaison avec la version trackée dans 20260819000005_journal_complet.sql :
-- corps identique mot pour mot (seul l'enrobage syntaxique diffère : tag de
-- dollar-quoting $function$ vs $$, et l'ordre des clauses LANGUAGE/SECURITY
-- DEFINER avant/après le corps — sans effet sur le comportement). Aucun écart
-- réel constaté ; la version déjà trackée était donc exacte.
CREATE OR REPLACE FUNCTION public.log_stop_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_person text;
  old_h hstore;
  new_h hstore;
  diff_h hstore;
  k text;
  excluded_cols text[] := array['updated_at', 'updated_by'];
begin
  select person_key into v_person from pin_unlocks
    where session_uid = auth.uid() and unlocked_until > now();

  old_h := hstore(old);
  new_h := hstore(new);
  diff_h := new_h - old_h;

  for k in select (each(diff_h)).key loop
    if k = any(excluded_cols) then
      continue;
    end if;
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, k, old_h->k, new_h->k, v_person);
  end loop;

  new.updated_at = now();
  new.updated_by = v_person;
  return new;
end;
$function$;

-- [CONFIRMÉ VERBATIM] Les 3 policies suivantes sont reconstruites mot pour mot
-- à partir de qual/with_check exacts sortis de pg_policies. Chacune est
-- encadrée d'un drop conditionnel car elle existe déjà en prod (la migration
-- doit rester rejouable sans erreur "policy already exists").
drop policy if exists "ajout_avec_pin" on stops;
create policy "ajout_avec_pin" on stops
  for insert to authenticated
  with check (
    exists (select 1 from pin_unlocks
      where pin_unlocks.session_uid = auth.uid()
        and pin_unlocks.unlocked_until > now())
  );

drop policy if exists "ecriture_avec_pin" on stops;
create policy "ecriture_avec_pin" on stops
  for update to authenticated
  using (true)
  with check (
    exists (select 1 from pin_unlocks
      where pin_unlocks.session_uid = auth.uid()
        and pin_unlocks.unlocked_until > now())
  );

drop policy if exists "lecture_avec_pin" on stops;
create policy "lecture_avec_pin" on stops
  for select to authenticated
  using (
    exists (select 1 from pin_unlocks
      where pin_unlocks.session_uid = auth.uid()
        and pin_unlocks.unlocked_until > now())
  );

-- Ajout non demandé explicitement dans ce message, mais nécessaire pour la
-- cohérence : "lecture_authentifie" et "ecriture_authentifie" (migration
-- 20260818000002, déjà fusionnée) accordaient un accès sans condition de PIN.
-- Si elles existent encore en prod à côté des 3 policies ci-dessus, les
-- policies permissives se combinent par OR en RLS : un accès sans condition
-- annulerait complètement la protection par PIN. On les retire ici pour que
-- rejouer les migrations depuis zéro reproduise l'état réel (PIN obligatoire),
-- pas un état hybride plus permissif. À confirmer via pg_policies qu'elles
-- sont bien absentes de la prod actuelle avant de fusionner.
drop policy if exists "lecture_authentifie" on stops;
drop policy if exists "ecriture_authentifie" on stops;
