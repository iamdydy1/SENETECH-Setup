# SENETECH Setup

**Version Stable officielle : V1.5.1**  
Windows 10 / 11 • Portable + Installé • Mises à jour intégrées

## Télécharger SENETECH

**[Télécharger SENETECH Setup V1.5.1 Stable](https://github.com/iamdydy1/SENETECH-Setup/releases/download/1.5.1/SENETECH-Setup-V1.5.1-FULL-STABLE.zip)**

Aucun compte GitHub, Git ou logiciel supplémentaire n'est nécessaire. Téléchargez le ZIP, extrayez-le entièrement puis lancez `SENETECH-Setup.exe`.

La page officielle de la version est disponible dans **Releases > 1.5.1**. Le fichier à distribuer aux utilisateurs est uniquement `SENETECH-Setup-V1.5.1-FULL-STABLE.zip`.

Une alternative automatisée est disponible avec `SENETECH-Download.cmd` : elle récupère toujours la dernière version Stable, vérifie son SHA-256 puis lance SENETECH.

## Fonctionnement

SENETECH est une seule application avec deux modes :

- **Portable** : fonctionne depuis un dossier ou une clé USB.
- **Installé** : peut être installé sur Windows avec raccourcis et désinstallation.

Le logiciel dispose de deux canaux de mise à jour :

- **Stable (`main`)** : canal par défaut, destiné aux clients et aux PC vendus.
- **Développeur (`develop`)** : canal réservé aux tests des prochaines fonctions.

Le canal se choisit depuis **Paramètres** dans SENETECH. Les nouvelles installations démarrent toujours en Stable.

## Mise à jour automatique

SENETECH lit le `version.json` du canal sélectionné. Lorsqu'une version plus récente est disponible, il télécharge le package officiel depuis GitHub Releases, contrôle son intégrité avec SHA-256, vérifie les fichiers indispensables, ferme l'application, remplace les fichiers, redémarre SENETECH puis nettoie les fichiers temporaires.

## Intégrité V1.5.1

- Package : `SENETECH-Setup-V1.5.1-FULL-STABLE.zip`
- Taille : `109004` octets
- SHA-256 : `81ab6caf1359ff9617bed74dffaad8a9e6e51c5c7043131ca51ee2e1f4c7332a`
- Release : `1.5.1`

## Développement

**V1.5.1 est la base Stable officielle.** `main` reste réservé aux versions validées. Toutes les prochaines modifications sont réalisées sur `develop`, testées, puis promues sur `main` uniquement après validation.

Ne publiez jamais de mot de passe, token GitHub ou clé privée dans ce dépôt public.
