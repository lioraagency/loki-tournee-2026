create view stops_public with (security_invoker = false) as
select
  id, nom, categorie, statut, statut_tag, prov, priorite, ville, city_key,
  approx, pertinence, adresse, contact, notes_mp, action, vedette, updated_at
from stops;

grant select on stops_public to anon, authenticated;
