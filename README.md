# SENETECH Setup

**Version Stable officielle : V1.5.1**  
Windows 10 / 11 • Portable + Installé • Mises à jour intégrées

## Télécharger SENETECH

**[Télécharger SENETECH Setup V1.5.1 Stable](https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/dist/SENETECH-Setup-V1.5.1-STABLE.zip)**

Aucun compte GitHub, Git ou logiciel supplémentaire n'est nécessaire. Téléchargez le ZIP, extrayez-le entièrement puis lancez `SENETECH-Setup.exe`.

Une alternative automatisée est disponible avec `SENETECH-Download.cmd` : elle récupère la dernière Stable, contrôle son SHA-256 et lance SENETECH.

## Fonctionnement

SENETECH est une seule application avec deux modes :

- **Portable** : fonctionne depuis un dossier ou une clé USB.
- **Installé** : peut être installé sur Windows avec raccourcis et désinstallation.

Le logiciel dispose également de deux canaux de mise à jour :

- **Stable (`main`)** : canal par défaut, destiné aux clients.
- **Développeur (`develop`)** : canal de test pour les prochaines fonctions.

Le canal se choisit depuis **Paramètres** dans SENETECH. Les nouvelles installations démarrent toujours en Stable.

## Mise à jour automatique

SENETECH lit le `version.json` du canal sélectionné. Lorsqu'une version plus récente est disponible, il télécharge le package complet, vérifie son SHA-256, ferme l'application, remplace les fichiers, redémarre SENETECH puis nettoie les fichiers temporaires.

## Intégrité V1.5.1

- Package : `dist/SENETECH-Setup-V1.5.1-STABLE.zip`
- Taille : `109004` octets
- SHA-256 : `81ab6caf1359ff9617bed74dffaad8a9e6e51c5c7043131ca51ee2e1f4c7332a`

## Développement

`main` reste la base Stable. Les prochaines modifications sont réalisées sur `develop`, testées, puis promues sur `main` uniquement après validation.

Ne publiez jamais de mot de passe, token GitHub ou clé privée dans ce dépôt public.
