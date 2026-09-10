# SENETECH Setup — Branche Développeur

Cette branche `develop` sert uniquement aux prochaines modifications et aux tests avant promotion vers `main`.

## Base actuelle

- Base : **SENETECH Setup V1.5.1**
- Stable officielle : branche `main`
- Package de référence : GitHub Release `1.5.1`
- Canal local : **Développeur**

La version Stable destinée aux utilisateurs reste disponible ici :

**[Télécharger SENETECH Setup V1.5.1 Stable](https://github.com/iamdydy1/SENETECH-Setup/releases/download/1.5.1/SENETECH-Setup-V1.5.1-FULL-STABLE.zip)**

## Règle de développement

Toutes les nouvelles fonctions sont développées et testées sur `develop`. Une version n'est publiée sur `main` qu'après validation.

Le `version.json` de cette branche pilote uniquement le canal Développeur. Tant qu'aucune version de test plus récente n'est publiée, il utilise la même base V1.5.1 que Stable.

Ne distribuez pas directement les fichiers de cette branche aux clients et ne publiez jamais de mot de passe, token GitHub ou clé privée dans ce dépôt public.
