# SENETECH Setup

SENETECH est une application Windows de préparation, diagnostic, installation d'applications et maintenance légère de PC.

## Base Stable officielle

La base Stable actuelle est **SENETECH V1.5.1**.

- Version : **1.5.1.0**
- Canal public : **Stable**
- Branche GitHub : **main**
- Windows : **10 / 11**
- Déploiement : **Portable + Installé**
- Package officiel complet : `dist/SENETECH-Setup-V1.5.1-STABLE.zip`
- SHA-256 : `81ab6caf1359ff9617bed74dffaad8a9e6e51c5c7043131ca51ee2e1f4c7332a`

**Le ZIP dans `dist/` est la référence Stable distribuée aux utilisateurs.** Il contient `SENETECH-Setup.exe`, le moteur `_SENETECH`, les assets et tous les fichiers runtime nécessaires.

## Une seule application, deux modes

### Mode Portable

SENETECH fonctionne depuis une clé USB ou un dossier, sans installation. Depuis l'interface, il peut aussi être installé sur le PC.

### Mode Installé

SENETECH peut être installé dans `C:\Program Files\SENETECH`, avec raccourcis Bureau / menu Démarrer, entrée dans Applications installées et désinstallation.

Portable et Installé restent la même application et utilisent le même système de mise à jour.

## Deux canaux

### Stable — `main`

Canal par défaut pour les clients et les PC vendus. Seules les versions validées doivent y être publiées.

### Développeur — `develop`

Canal de test. Les nouvelles fonctions sont développées et testées ici avant promotion sur `main`.

Depuis V1.5.1, **Paramètres** permet de choisir Stable ou Développeur. Le choix est mémorisé localement. Une nouvelle installation client démarre toujours en Stable.

## Mise à jour

Le bouton **Mise à jour** consulte le `version.json` du canal choisi, télécharge le package, contrôle son SHA-256, ferme SENETECH, remplace les fichiers, relance l'application puis nettoie les fichiers temporaires.

## Règle de développement

**V1.5.1 Stable est la base de référence.** Toutes les prochaines modifications commencent sur `develop`. Après test et validation, une version peut être promue sur `main`.

Ne jamais mettre de mot de passe, token GitHub ou clé privée dans ce dépôt public.
