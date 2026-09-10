# Changelog SENETECH Setup

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
- Les modes Portable et Installé utilisent le **même `version.json` et le même dépôt GitHub**.
- En mode Installé, SENETECH vérifie automatiquement les nouvelles versions quelques secondes après son lancement.
- Le bouton manuel **Mise à jour** reste disponible dans les deux modes.
- Distribution V1.5.0 réalisée avec un moteur reconstruit depuis des fragments texte vérifiés et un contrôle SHA-256 avant installation.

## V1.4.3 — Test GitHub — 2026-09-10

- Publication d'une **V1.4.3 de test** afin de valider le passage réel depuis V1.4.2.
- La V1.4.2 détecte V1.4.3 via `version.json`.
- Réutilisation du package de base V1.4.2 déjà présent sur GitHub au lieu de dupliquer l'application entière.
- Ajout d'un patch léger V1.4.3.
- Vérification SHA-256 du package de base et du patch avant installation.
- Remplacement effectué uniquement après fermeture de SENETECH, puis redémarrage automatique.
- Nettoyage des fichiers temporaires conservé après la mise à jour.

## V1.4.2 — 2026-09-10

- Bouton **Mise à jour** intégré directement dans l'interface.
- Vérification de la version distante via `version.json` sur GitHub.
- Affichage des notes de version avant installation d'une nouvelle version.
- Demande de confirmation avant toute mise à jour.
- Transmission du PID de SENETECH pour attendre sa fermeture avant remplacement.
- Vérification SHA-256 des packages.
- Nettoyage automatique des fichiers temporaires après chaque mise à jour.
- Cache hors ligne optimisé : une seule version d'installateur est conservée par application.
- Les pilotes hors ligne et les rapports utilisateur restent conservés.

## V1.3 — 2026-09-10

- Nouvelle interface graphique SENETECH.
- Intégration du logo SENETECH dans l'application.
- Maintien du fonctionnement portable depuis clé USB.
- Profils d'installation revus et enrichis, notamment le profil Gamer.

## V1.2

- Version moteur de référence historique.
