# SENETECH Setup — Develop

> **Canal de développement. Ne pas distribuer directement aux clients.**

Version de travail : **V1.6.0 DEV**  
Base Stable publique : **V1.5.1** sur `main`

## Objectif V1.6

SENETECH évolue d'un outil d'installation vers un véritable assistant de préparation PC pour technicien : diagnostic, logiciels, mises à jour, sécurité, optimisation réversible, nettoyage et rapport final.

### Fonctions V1.6 en cours de test

- **PRÉPARER CE PC** : workflow de préparation guidé.
- Catalogue d'applications dynamique (`catalog/apps.json`).
- Profils dynamiques (`catalog/profiles.json`) : Essentiel, Bureautique, Étudiant, Gaming, Créateur, Développement, PC léger et Personnalisé.
- Installation d'applications avec langue Windows préférée lorsque WinGet la propose.
- Mise à jour des applications déjà installées via WinGet.
- Point de restauration Windows avant les modifications.
- Optimisations Gaming / PC léger limitées et réversibles.
- Gestion des applications de démarrage avec sauvegarde/restauration.
- Nettoyage des fichiers temporaires et de la Corbeille.
- Windows Update avancé : logiciels, pilotes, mises à jour facultatives/Preview sur choix explicite.
- Diagnostics enrichis : CPU, GPU, RAM, stockage, batterie, cycles lorsque disponibles, TPM, Secure Boot, activation et périphériques en erreur.
- Historique local des opérations SENETECH.
- Recovery externe et diagnostics Developer renforcés.
- Préparation d'une signature Authenticode pour les futures versions publiques.

## Nouvelle architecture d'installation

GitHub reste la source de vérité pour les branches, versions, manifests, changelogs et releases.

La cible pour la version **installable** est désormais un **installateur complet Inno Setup par version**, et non une chaîne de patches appliqués directement dans `Program Files`.

Exemple d'asset GitHub Release :

`SENETECH-Setup-1.6.0.27-DEV.exe`

Une fois installé, l'exécutable garde toujours le même nom et le même chemin :

`C:\Program Files\SENETECH\SENETECH-Setup.exe`

Le même `AppId` Inno Setup est conservé sur toutes les versions afin que Windows reconnaisse chaque nouvelle build comme une mise à jour de la même application.

Documentation complète : [`INSTALLER-ARCHITECTURE.md`](INSTALLER-ARCHITECTURE.md).

## Construction du nouvel installateur

- `tools/Prepare-SenetechFullPackage.ps1` : assemble un runtime complet à partir du `version.json` local du commit testé.
- `installer/SENETECH.iss` : définition Inno Setup.
- `tools/Build-SenetechInstaller.ps1` : compile l'installateur et génère son SHA-256 + metadata.
- `.github/workflows/build-installer.yml` : construit et teste une installation propre puis une installation par-dessus l'ancienne.

Le test d'upgrade vérifie notamment qu'un ancien fichier placé dans `_SENETECH` est supprimé et qu'il ne reste qu'un seul `SENETECH-Setup.exe` après la mise à jour.

## Ancien updater — mode transition / Recovery

Le mécanisme historique basé sur Stable V1.5.1 + patch + overlays est conservé temporairement pour permettre la récupération des builds actuelles.

Il ne doit plus être considéré comme l'architecture finale pour les futures versions installables. Après validation du premier installateur complet Developer, le bouton **Mise à jour** devra télécharger l'installateur complet depuis GitHub Releases, vérifier sa taille et son SHA-256, fermer SENETECH puis laisser Inno Setup remplacer le runtime.

## Portable

La version Portable reste indépendante : un ZIP complet peut continuer à être publié à côté de l'installateur Windows dans la même GitHub Release.

## Recovery

La Recovery reste indépendante du runtime installé et doit pouvoir être conservée sur clé USB. Elle ne doit jamais dépendre du bon fonctionnement de l'updater intégré.

## Tester depuis une version existante

Pour l'instant, la Recovery actuelle reste le filet de sécurité. Le premier installateur complet Developer doit être testé manuellement avant que le mécanisme intégré de mise à jour soit basculé vers Inno Setup.

`main` ne reçoit aucune modification V1.6 avant validation explicite.
