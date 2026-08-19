alter table stops add constraint categorie_valide
check (categorie in ('Porsche','Golf','Contenu','Automobile','Sports','Événements','Contacts','Vigilance'));
