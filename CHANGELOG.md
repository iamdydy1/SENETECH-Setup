# Changelog SENETECH Setup

## V1.5.1 — Base Stable — 2026-09-10

- **V1.5.1 devient la base Stable officielle de SENETECH.**
- Séparation des canaux : `main` = **Stable**, `develop` = **Développeur**.
- Ajout de **Paramètres** pour choisir le canal Stable ou Développeur.
- Le canal choisi est mémorisé localement.
- Une nouvelle installation destinée à un client démarre toujours en **Stable**.
- Modes **Portable** et **Installé** conservés dans une seule application.
- Ajout de `SENETECH-Download.cmd` comme téléchargeur public simplifié.
- Nettoyage du dépôt Stable : suppression de l'ancien EXE isolé et du ZIP incomplet afin d'éviter les mauvais téléchargements.
- Mise à jour depuis V1.4.3 maintenue via le package GitHub vérifié + patch V1.5.1.
- Les prochaines modifications fonctionnelles sont développées sur `develop` avant promotion sur `main`.

## V1.5.0 — Portable + Installé — 2026-09-10

- Une seule application SENETECH avec deux modes : **Portable** et **Installé**.
- Le mode actif est affiché directement dans l'interface.
- Nouveau bouton **Installer SENETECH sur ce PC** lorsque l'application tourne en mode Portable.
- Installation dans `C:\Program Files\SENETECH`.
- Création d'un raccourci sur le Bureau et dans le menu Démarrer.
- SENETECH apparaît dans **Applications installées** de Windows.
- Ajout d'un désinstalleur SENETECH avec confirmation avant suppression.
- Nouvelle option **Installer SENETECH automatiquement à la fin de la préparation**.
- Les caches lourds d'applications et de pilotes de la clé ne sont pas copiés dans `Program Files`.
- En mode Installé, SENETECH vérifie automatiquement les nouvelles versions après son lancement.

## V1.4.3 — Test GitHub — 2026-09-10

- Validation réelle du passage V1.4.2 → V1.4.3 depuis GitHub.
- Détection via `version.json`.
- Vérification SHA-256 du package de base.
- Remplacement après fermeture de SENETECH et redémarrage automatique.
- Nettoyage des fichiers temporaires après mise à jour.

## V1.4.2 — 2026-09-10

- Bouton **Mise à jour** intégré dans l'interface.
- Vérification de la version distante via GitHub.
- Notes de version et confirmation avant installation.
- Attente de fermeture de SENETECH avant remplacement.
- Nettoyage automatique des fichiers temporaires.
- Cache hors ligne optimisé.

## V1.3 — 2026-09-10

- Nouvelle interface graphique SENETECH.
- Intégration du logo SENETECH.
- Fonctionnement portable depuis clé USB.
- Profils d'installation enrichis.

## V1.2

- Version moteur de référence historique.
