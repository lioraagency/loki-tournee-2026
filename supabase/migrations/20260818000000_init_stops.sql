-- Table principale : remplace le bloc EXPORT.data actuel
create table stops (
  id text primary key,                          -- garder les ids existants (mb-1, bc-4...) pour continuité
  nom text not null,
  categorie text not null,
  statut text,                                    -- nouveau / confirme / clarifier (existant)
  statut_tag text,                                -- NOUVEAU : "Main Event", "Priorité élevée", etc. — libre
  prov text,
  priorite text,
  ville text,
  city_key text,
  approx boolean default false,
  pertinence text,
  adresse text,
  contact text,
  contact_nom text,
  contact_role text,
  contact_tel text,
  contact_courriel text,
  notes_mp text,
  action text,
  vedette boolean default false,
  updated_at timestamptz default now(),
  updated_by uuid references auth.users(id)
);

create table taches (
  id uuid primary key default gen_random_uuid(),
  stop_id text references stops(id) on delete cascade,
  texte text not null,
  complete boolean default false,
  assigne_a uuid references auth.users(id),
  date_echeance date,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create table notes (
  id uuid primary key default gen_random_uuid(),
  stop_id text references stops(id) on delete cascade,
  texte text not null,
  auteur uuid references auth.users(id),
  created_at timestamptz default now()
);

create table activity_log (
  id uuid primary key default gen_random_uuid(),
  stop_id text references stops(id) on delete cascade,
  champ_modifie text,
  ancienne_valeur text,
  nouvelle_valeur text,
  modifie_par uuid references auth.users(id),
  modifie_le timestamptz default now()
);

create table pieces_jointes (
  id uuid primary key default gen_random_uuid(),
  stop_id text references stops(id) on delete cascade,
  nom_fichier text,
  url text,
  uploaded_by uuid references auth.users(id),
  uploaded_at timestamptz default now()
);
