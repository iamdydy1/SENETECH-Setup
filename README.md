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
- Sauvegarde de la version SENETECH précédente et bouton de rollback.
- Préparation d'une signature Authenticode pour les futures versions publiques.

## Mise à jour du canal Develop

Le canal `develop` n'a pas besoin d'un nouveau ZIP complet à chaque modification. L'updater télécharge la **V1.5.1 Stable vérifiée par SHA-256** comme base, applique le patch V1.6 puis récupère les modules du canal `develop`.

Le catalogue d'applications et les profils peuvent donc évoluer sans reconstruire l'exécutable. Une modification du moteur nécessitant un nouveau test doit recevoir un numéro de version développeur supérieur dans `version.json`.

## Tester depuis V1.5.1

Dans SENETECH V1.5.1 : **Paramètres → Canal de mise à jour → Développeur**. SENETECH doit détecter V1.6.0 DEV, proposer la mise à jour, sauvegarder la version actuelle, appliquer les fichiers V1.6 et redémarrer.

En cas de problème, la Stable V1.5.1 reste intacte sur `main` et dans sa GitHub Release.

## Organisation

- `catalog/` : applications et profils dynamiques.
- `src/Modules/` : fonctionnalités V1.6.
- `src/Moteur-WindowsUpdate.ps1` : moteur Windows Update avancé.
- `src/PATCH-SENETECH-1.6.0-v2.ps1` : transformation déterministe de la base Stable vers V1.6 DEV.
- `UPDATE-SENETECH.ps1` : updater du canal Develop avec vérifications et rollback.
- `tools/` : construction manuelle et signature future.

`main` ne reçoit aucune modification V1.6 avant validation explicite.
