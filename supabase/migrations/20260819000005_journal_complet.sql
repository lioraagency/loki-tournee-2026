create extension if not exists hstore;

create or replace function log_stop_changes()
returns trigger as $$
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
$$ language plpgsql security definer;
