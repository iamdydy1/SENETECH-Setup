# SENETECH Setup

SENETECH est une application Windows de préparation, diagnostic, installation d'applications et maintenance légère de PC.

## Version de test actuelle

- Version : **1.5.0.0**
- Affichage : **V1.5.0**
- Canal : **test**
- Windows : **10 / 11**
- Déploiement : **Portable + Installé**

## Une seule application, deux modes

### Mode Portable

SENETECH peut fonctionner directement depuis une clé USB ou un dossier, sans installation. Ce mode conserve les outils de préparation, le cache hors ligne, les pilotes et les rapports sur le support utilisé.

Depuis l'interface V1.5.0, le bouton **Installer SENETECH sur ce PC** permet de transformer la même application en installation Windows permanente.

### Mode Installé

Le runtime SENETECH est installé dans :

`C:\Program Files\SENETECH`

L'installation crée :

- un raccourci Bureau ;
- un raccourci dans le menu Démarrer ;
- une entrée **SENETECH Setup** dans les Applications installées de Windows ;
- un désinstalleur intégré ;
- un marqueur local indiquant que SENETECH tourne en mode Installé.

Les caches lourds de la clé USB ne sont pas copiés dans `Program Files`.

## Un seul système de mise à jour

Portable et Installé utilisent exactement le même dépôt et le même `version.json`.

Le bouton **Mise à jour** :

1. lit `version.json` sur GitHub ;
2. compare la version locale et la version distante ;
3. affiche les notes de version ;
4. demande confirmation ;
5. télécharge et vérifie les composants de mise à jour ;
6. ferme SENETECH ;
7. remplace les fichiers nécessaires ;
8. relance l'application ;
9. nettoie les fichiers temporaires.

En mode **Installé**, une vérification silencieuse est également effectuée quelques secondes après le lancement. Si une nouvelle version existe, l'utilisateur reçoit ensuite la proposition de mise à jour habituelle.

## Installation automatique après préparation

En mode Portable, la case **Installer SENETECH automatiquement à la fin de la préparation** permet à un technicien de préparer un PC puis d'y laisser SENETECH installé pour le client.

## Sécurité des mises à jour

Le package de base et les patchs peuvent être contrôlés par SHA-256 avant installation. La V1.5.0 reconstruit également son moteur depuis des fragments versionnés sur GitHub puis vérifie l'empreinte du moteur complet avant remplacement.

Le moteur de mise à jour nettoie `%TEMP%\SENETECH-Update` après installation et limite l'accumulation de fichiers temporaires.

Ne jamais mettre de mot de passe, token GitHub ou clé privée dans ce dépôt public.
