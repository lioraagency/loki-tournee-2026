create or replace function delete_note_with_pin(p_note_id uuid, p_person_key text, p_pin text)
returns boolean as $$
declare
  rec user_pins%rowtype;
  note_rec notes%rowtype;
  ok boolean;
  session_person text;
begin
  if auth.uid() is null then
    raise exception 'Session invalide, recharge la page.';
  end if;

  select person_key into session_person from pin_unlocks
    where session_uid = auth.uid() and unlocked_until > now();
  if session_person is null or session_person <> lower(p_person_key) then
    raise exception 'Identité de session invalide. Reconnecte-toi avec ton nom et ton PIN.';
  end if;

  select * into rec from user_pins where person_key = lower(p_person_key);
  if not found then
    return false;
  end if;
  if rec.locked_until is not null and rec.locked_until > now() then
    raise exception 'Compte temporairement verrouillé, réessaie plus tard.';
  end if;

  ok := (rec.pin_hash = crypt(p_pin, rec.pin_hash));
  if not ok then
    update user_pins
      set failed_attempts = failed_attempts + 1,
          locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
      where person_key = lower(p_person_key);
    return false;
  end if;

  update user_pins set failed_attempts = 0, locked_until = null where person_key = lower(p_person_key);

  delete from notes where id = p_note_id returning * into note_rec;
  if note_rec.id is null then
    return false;
  end if;

  insert into activity_log(stop_id, champ_modifie, ancienne_valeur, nouvelle_valeur, modifie_par)
  values (note_rec.stop_id, 'note_supprimee', note_rec.texte, null, p_person_key);

  return true;
end;
$$ language plpgsql security definer;
