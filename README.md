# SENETECH Setup

Application portable SENETECH destinée à préparer et configurer les PC Windows.

## Version stable actuelle

- Version interne : **1.4.2.0**
- Affichage : **V1.4.2**
- Canal : **stable**
- Lanceur : `SENETECH-Setup.exe`

## Mise à jour intégrée à V1.4.2

La source V1.4.2 intègre maintenant directement un bouton **Mise à jour** dans l'interface SENETECH.

Quand l'utilisateur clique dessus, l'application :

1. vérifie la connexion Internet ;
2. lit `version.json` depuis ce dépôt ;
3. compare la version installée avec la version distante ;
4. confirme que V1.4.2 est à jour si aucune version supérieure n'existe ;
5. affiche les notes de version lorsqu'une nouvelle version est disponible ;
6. demande confirmation avant installation ;
7. télécharge le moteur `UPDATE-SENETECH.ps1` ;
8. transmet le PID de SENETECH à l'updater ;
9. ferme proprement l'application ;
10. l'updater remplace les fichiers puis relance `SENETECH-Setup.exe`.

## `version.json`

Le manifeste distant contient :

- la dernière version disponible ;
- l'état d'activation des mises à jour ;
- le caractère obligatoire ou non de la mise à jour ;
- l'URL du package ZIP ;
- son empreinte SHA-256 ;
- les notes de version.

## `UPDATE-SENETECH.ps1`

Le moteur de mise à jour :

1. vérifie à nouveau la version distante ;
2. télécharge le ZIP de la nouvelle version ;
3. vérifie son SHA-256 lorsqu'il est renseigné ;
4. extrait les fichiers dans un dossier temporaire ;
5. attend la fermeture du processus SENETECH ;
6. remplace les fichiers de l'application ;
7. relance `SENETECH-Setup.exe`.

Le journal d'update est écrit dans `%TEMP%\SENETECH-Update.log`.

## Publication d'une future version

Exemple pour **V1.4.3** :

1. Générer le nouveau dossier SENETECH puis `SENETECH-Setup.exe`.
2. Créer un ZIP dont le contenu de l'application est directement à la racine du ZIP pour l'updater.
3. Publier le ZIP sur GitHub.
4. Calculer le SHA-256 du ZIP.
5. Modifier `version.json` :
   - `version` → `1.4.3.0`
   - `displayVersion` → `1.4.3`
   - `enabled` → `true`
   - `downloadUrl` → URL directe du ZIP
   - `sha256` → empreinte SHA-256 du ZIP
   - `releaseNotes` → nouveautés de la version
6. Tester la mise à jour depuis une V1.4.2 avant diffusion générale.

## Sécurité

Ne jamais mettre de mot de passe, token GitHub ou clé privée dans ce dépôt public.
