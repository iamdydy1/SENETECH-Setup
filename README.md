# SENETECH Setup

SENETECH est une application Windows de préparation, diagnostic, installation d'applications et maintenance légère de PC.

## Base Stable officielle

La base Stable actuelle est **SENETECH V1.5.1**.

- Version : **1.5.1.0**
- Canal public : **Stable**
- Branche GitHub : **main**
- Windows : **10 / 11**
- Déploiement : **Portable + Installé**
- Package officiel : `dist/SENETECH-Setup-V1.5.1-STABLE.zip`

Le package Stable est un runtime complet : il contient `SENETECH-Setup.exe`, le moteur `_SENETECH`, les assets et les fichiers nécessaires. Les mises à jour Stable téléchargent directement ce package complet et vérifient son SHA-256 avant remplacement.

## Une seule application, deux modes

### Mode Portable

SENETECH peut fonctionner directement depuis une clé USB ou un dossier, sans installation. Il peut ensuite être installé sur le PC depuis l'interface.

### Mode Installé

SENETECH peut être installé dans `C:\Program Files\SENETECH`, avec raccourcis Bureau / menu Démarrer, entrée dans Applications installées et désinstallation.

Portable et Installé restent la même application et utilisent le même système de mise à jour.

## Deux canaux de mise à jour

### Stable — `main`

Canal recommandé et utilisé par défaut pour les clients et les PC vendus. Seules les versions validées y sont publiées.

### Développeur — `develop`

Canal destiné aux tests et aux futures fonctions. Une version est développée et testée ici avant d'être promue sur `main`.

Depuis SENETECH V1.5.1, le canal peut être choisi dans **Paramètres**. Le choix est mémorisé localement. Une nouvelle installation client démarre toujours sur Stable.

## Mise à jour

Le bouton **Mise à jour** :

1. consulte le `version.json` du canal sélectionné ;
2. compare la version locale et distante ;
3. affiche les notes de version ;
4. télécharge le package ;
5. vérifie son SHA-256 ;
6. ferme SENETECH ;
7. remplace les fichiers ;
8. relance l'application ;
9. nettoie les fichiers temporaires.

En mode Installé, SENETECH peut également vérifier automatiquement les mises à jour après le lancement.

## Règle de développement

**V1.5.1 Stable est désormais la base de référence.** Les nouvelles modifications doivent être faites sur `develop`. Une fois testées et validées, elles peuvent être promues sur `main` avec une nouvelle version Stable.

Ne jamais mettre de mot de passe, token GitHub ou clé privée dans ce dépôt public.
