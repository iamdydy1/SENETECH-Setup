# Politique de stockage SENETECH

SENETECH doit rester leger sur les PC et dans les packages distribues.

- Les mises a jour sont telechargees dans `%TEMP%\SENETECH-Update` puis supprimees automatiquement apres installation.
- Le ZIP de mise a jour est supprime des qu'il a ete extrait.
- Le dossier temporaire d'extraction est supprime apres redemarrage de SENETECH.
- Le journal d'update est limite : au-dela de 1 Mo, il est recree.
- Les applications ne sont pas embarquees dans le package principal sauf besoin hors ligne explicite.
- Pour le cache hors ligne, SENETECH conserve une seule version d'installateur par application. Une actualisation reussie remplace l'ancienne version.
- En cas d'echec de telechargement d'une nouvelle version d'application, l'ancien installateur reste conserve.
- Les pilotes hors ligne et les rapports utilisateur ne sont pas supprimes automatiquement.

Objectif : permettre de nombreuses mises a jour successives sans accumulation inutile de fichiers sur le PC ou la cle USB.
