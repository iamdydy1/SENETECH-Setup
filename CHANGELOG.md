# Changelog SENETECH Setup

## V1.4.3 — Test GitHub — 2026-09-10

- Publication d'une **V1.4.3 de test** afin de valider le passage réel depuis V1.4.2.
- La V1.4.2 détecte désormais V1.4.3 via `version.json`.
- Réutilisation du package de base V1.4.2 déjà présent sur GitHub au lieu de dupliquer l'application entière.
- Ajout d'un patch léger V1.4.3 d'environ 3 Ko.
- Vérification SHA-256 du package de base et du patch avant installation.
- Le patch met à jour la version de l'interface, du moteur, du manifeste et des métadonnées de l'EXE vers **1.4.3.0**.
- Remplacement effectué uniquement après fermeture de SENETECH, puis redémarrage automatique.
- Nettoyage des fichiers temporaires conservé après la mise à jour.

## V1.4.2 — 2026-09-10

- Version stable actuelle définie sur **1.4.2.0**.
- Bouton **Mise à jour** intégré directement dans l'interface V1.4.2.
- Vérification de la version distante via `version.json` sur GitHub.
- Message **SENETECH V1.4.2 est déjà à jour** lorsqu'aucune version supérieure n'existe.
- Affichage des notes de version avant installation d'une nouvelle version.
- Demande de confirmation avant toute mise à jour.
- Téléchargement du moteur d'update depuis le dépôt officiel.
- Transmission du PID de SENETECH pour attendre sa fermeture avant remplacement.
- Téléchargement et extraction du futur package ZIP.
- Vérification SHA-256 du package lorsqu'une nouvelle version est publiée.
- Remplacement des fichiers puis relance automatique de `SENETECH-Setup.exe`.
- Nettoyage automatique des fichiers temporaires après chaque mise à jour.
- Suppression du ZIP de mise à jour dès son extraction terminée.
- Le dossier `%TEMP%\SENETECH-Update` est réutilisé au lieu d'accumuler plusieurs versions.
- Le journal d'update est recréé lorsqu'il dépasse 1 Mo.
- Cache hors ligne optimisé : une seule version d'installateur doit être conservée par application.
- Les anciennes versions d'une application sont remplacées uniquement après téléchargement réussi de la nouvelle.
- Les pilotes hors ligne et les rapports utilisateur restent conservés.
- Journal d'update dans `%TEMP%\SENETECH-Update.log`.
- Compatibilité Windows PowerShell conservée.

## V1.3 — 2026-09-10

- Nouvelle interface graphique SENETECH.
- Intégration du logo SENETECH dans l'application.
- Amélioration de la lisibilité de l'interface et de l'identité visuelle.
- Maintien du fonctionnement portable depuis clé USB.
- Profils d'installation revus et enrichis, notamment le profil Gamer.
- Préparation d'une sélection d'applications adaptée à la langue du Windows utilisé.

## V1.2

- Version moteur de référence historique.
