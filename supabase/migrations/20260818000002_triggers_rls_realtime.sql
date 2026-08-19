create or replace function log_stop_changes()
returns trigger as $$
begin
  if old.statut_tag is distinct from new.statut_tag then
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, 'statut_tag', old.statut_tag, new.statut_tag, auth.uid());
  end if;
  if old.contact_nom is distinct from new.contact_nom then
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, 'contact_nom', old.contact_nom, new.contact_nom, auth.uid());
  end if;
  if old.contact_role is distinct from new.contact_role then
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, 'contact_role', old.contact_role, new.contact_role, auth.uid());
  end if;
  if old.contact_tel is distinct from new.contact_tel then
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, 'contact_tel', old.contact_tel, new.contact_tel, auth.uid());
  end if;
  if old.contact_courriel is distinct from new.contact_courriel then
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, 'contact_courriel', old.contact_courriel, new.contact_courriel, auth.uid());
  end if;
  if old.action is distinct from new.action then
    insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
    values (new.id, 'action', old.action, new.action, auth.uid());
  end if;
  new.updated_at = now();
  new.updated_by = auth.uid();
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_log_stop_changes
before update on stops
for each row execute function log_stop_changes();

alter table stops enable row level security;
alter table taches enable row level security;
alter table notes enable row level security;
alter table activity_log enable row level security;
alter table pieces_jointes enable row level security;

create policy "lecture_authentifie" on stops for select to authenticated using (true);
create policy "ecriture_authentifie" on stops for update to authenticated using (true) with check (true);

create policy "taches_lecture" on taches for select to authenticated using (true);
create policy "taches_ecriture" on taches for insert to authenticated with check (true);
create policy "taches_maj" on taches for update to authenticated using (true) with check (true);

create policy "notes_lecture" on notes for select to authenticated using (true);
create policy "notes_ecriture" on notes for insert to authenticated with check (true);

create policy "log_lecture" on activity_log for select to authenticated using (true);

create policy "pj_lecture" on pieces_jointes for select to authenticated using (true);
create policy "pj_ecriture" on pieces_jointes for insert to authenticated with check (true);

alter publication supabase_realtime add table stops;
alter publication supabase_realtime add table taches;
alter publication supabase_realtime add table notes;
