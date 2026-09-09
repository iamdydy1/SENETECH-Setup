# SENETECH Setup

Application portable SENETECH destinée à préparer et configurer les PC Windows.

## Version stable actuelle

- Version interne : **1.4.2.0**
- Affichage : **V1.4.2**
- Canal : **stable**
- Lanceur : `SENETECH-Setup.exe`

## Système de mise à jour GitHub

Le dépôt sert de source officielle pour les futures mises à jour de SENETECH.

### `version.json`

Le manifeste distant indique :

- la dernière version disponible ;
- si le service de mise à jour est activé ;
- si la mise à jour est importante ;
- l'URL du package ZIP ;
- le SHA-256 du package ;
- les notes de version.

### `CHECK-SENETECH-UPDATE.ps1`

C'est le point d'entrée destiné à l'interface SENETECH V1.4.2.

Il :

1. contacte le dépôt GitHub ;
2. compare V1.4.2 avec la version distante ;
3. affiche une fenêtre si une nouvelle version existe ;
4. présente les notes de version ;
5. laisse l'utilisateur accepter ou reporter la mise à jour ;
6. lance le moteur de mise à jour en arrière-plan.

Code de sortie `10` : la mise à jour a été acceptée. L'application SENETECH doit alors se fermer afin de permettre le remplacement de son exécutable.

### `UPDATE-SENETECH.ps1`

Le moteur de mise à jour :

1. vérifie à nouveau la version distante ;
2. télécharge le ZIP de la nouvelle version ;
3. vérifie son SHA-256 ;
4. extrait les fichiers dans un dossier temporaire ;
5. attend la fermeture du processus SENETECH si son PID a été transmis ;
6. remplace les fichiers ;
7. relance `SENETECH-Setup.exe`.

Un journal est écrit dans `%TEMP%\SENETECH-Update.log`.

## Intégration dans V1.4.2

Le bouton **Rechercher les mises à jour** de l'application doit lancer :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "CHECK-SENETECH-UPDATE.ps1" -CurrentVersion "1.4.2.0" -InstallDir "<dossier SENETECH>" -HostProcessId <PID SENETECH>
```

Si le processus retourne le code `10`, SENETECH doit fermer sa fenêtre principale et quitter normalement. L'updater attendra ensuite sa fermeture avant de remplacer les fichiers.

## Publication d'une future version

Exemple pour V1.4.3 :

1. Générer `SENETECH-Setup-V1.4.3.zip`.
2. Publier le ZIP dans une GitHub Release avec un tag comme `v1.4.3`.
3. Calculer le SHA-256 du ZIP.
4. Mettre à jour `version.json` :
   - `version` → `1.4.3.0`
   - `displayVersion` → `1.4.3`
   - `enabled` → `true`
   - `downloadUrl` → URL directe du ZIP de la Release
   - `sha256` → empreinte SHA-256 du ZIP
   - `releaseNotes` → nouveautés de la version
5. Tester sur un PC SENETECH avant diffusion générale.

## Sécurité

Une mise à jour dont le SHA-256 ne correspond pas au manifeste est annulée.

Ne jamais mettre de mot de passe, token GitHub ou clé privée dans ce dépôt public.
