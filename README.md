# SENETECH Setup

**Base Stable officielle : V1.5.1**  
Windows 10 / 11 • Portable + Installé • Mises à jour GitHub

## Pour les utilisateurs

Ne téléchargez pas les fichiers du dépôt un par un et ne récupérez pas `SENETECH-Setup.exe` isolément.

Deux méthodes sont prévues :

1. **ZIP officiel SENETECH V1.5.1 FULL** : extraire entièrement le ZIP puis lancer `SENETECH-Setup.exe`.
2. **`SENETECH-Download.cmd`** : télécharge automatiquement la version Stable dans `Téléchargements\SENETECH-Setup`, vérifie le package puis lance SENETECH.

**Aucun compte GitHub n'est nécessaire.** Le dépôt est public et SENETECH utilise GitHub uniquement comme serveur de versions et de mises à jour.

## Base Stable

- Version : **1.5.1.0**
- Canal : **Stable**
- Branche : **`main`**
- Déploiement : **Portable + Installé**
- Mise à jour : activée
- Windows : **10 / 11**

`version.json` est la source officielle utilisée par SENETECH pour connaître la version Stable disponible.

## Portable ou Installé

**Portable** : SENETECH fonctionne depuis un dossier ou une clé USB sans installation permanente.

**Installé** : le même SENETECH peut être installé sur le PC avec ses raccourcis et sa désinstallation.

Il s'agit d'une seule application : le mode de déploiement ne change pas le système de mise à jour.

## Stable ou Développeur

- **Stable — `main`** : canal recommandé pour les clients et les PC vendus.
- **Développeur — `develop`** : canal utilisé pour tester les prochaines modifications avant leur validation.

Depuis V1.5.1, le canal peut être choisi dans **Paramètres**. Une nouvelle installation destinée à un client démarre toujours en Stable.

## Mises à jour

SENETECH vérifie le `version.json` du canal sélectionné. Lorsqu'une version plus récente existe, il la propose, télécharge les fichiers nécessaires, vérifie le package, ferme l'application, applique la mise à jour, redémarre SENETECH puis nettoie ses fichiers temporaires.

## Règle de développement

**V1.5.1 est notre base Stable.** Toutes les nouvelles modifications sont réalisées sur `develop`. Elles ne passent sur `main` qu'après test et validation.

Ne jamais publier de mot de passe, token GitHub ou clé privée dans ce dépôt public.
