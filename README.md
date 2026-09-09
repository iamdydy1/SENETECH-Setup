# SENETECH Setup

Application portable SENETECH destinée à préparer et configurer les PC Windows.

## Version stable

- Version : **1.3.0.0**
- Affichage : **V1.3**
- Canal : **stable**
- Lanceur : `SENETECH-Setup.exe`
- Moteur interne : `_SENETECH`

## Mise à jour automatique

Le dépôt sert de source officielle pour les mises à jour de SENETECH.

Le fichier `version.json` indique :

- la dernière version disponible ;
- si la mise à jour est activée ;
- si elle est obligatoire ;
- l'URL du package ZIP ;
- le SHA-256 du package ;
- les notes de version.

Le script `UPDATE-SENETECH.ps1` :

1. lit `version.json` depuis GitHub ;
2. compare la version distante avec la version installée ;
3. télécharge le ZIP uniquement si une version plus récente existe ;
4. vérifie le SHA-256 lorsqu'il est renseigné ;
5. extrait la nouvelle version ;
6. applique les nouveaux fichiers puis relance `SENETECH-Setup.exe`.

## Publication d'une nouvelle version

Exemple pour une future V1.4 :

1. Générer `SENETECH-Setup-V1.4.zip`.
2. Publier le ZIP dans une GitHub Release, par exemple avec le tag `v1.4.0`.
3. Calculer le SHA-256 du ZIP.
4. Mettre à jour `version.json` :
   - `version` → `1.4.0.0`
   - `displayVersion` → `1.4`
   - `enabled` → `true`
   - `downloadUrl` → URL du fichier de la Release
   - `sha256` → empreinte SHA-256 du ZIP
   - `releaseNotes` → nouveautés de la version
5. Tester sur un PC SENETECH avant diffusion générale.

## Sécurité

Une mise à jour dont le SHA-256 ne correspond pas au manifeste est annulée.

Ne jamais mettre de mot de passe, token GitHub ou clé privée dans ce dépôt public.
