# Changelog SENETECH Setup — Develop

## V1.6.0.8 DEV — 2026-09-10

- Ajout du module `Senetech.Display.ps1` pour adapter automatiquement la fenêtre à la résolution et au DPI Windows.
- Sur les petits écrans, notamment 1366×768, SENETECH passe automatiquement en mode **Compact** et utilise toute la zone de travail disponible.
- Sur les écrans Full HD et supérieurs, la fenêtre conserve des dimensions confortables sans dépasser la zone visible.
- Les dimensions minimales/maximales sont adaptées au poste afin d'éviter les éléments coupés ou hors écran.
- WPF conserve la gestion DPI native ; SENETECH ne modifie pas la résolution Windows de l'utilisateur.
- Le journal affiche la résolution détectée, le DPI, le pourcentage de mise à l'échelle et le profil d'affichage choisi.
- La Stable V1.5.1 reste inchangée ; ce correctif doit être validé sur le laptop avant promotion.

## V1.6.0.7 DEV — 2026-09-10

- Correction du cas Windows 10 où **Microsoft Desktop App Installer est déjà installé dans une version récente**, mais où `winget.exe` n'est pas résolu par l'alias WindowsApps.
- SENETECH recherche directement `winget.exe` dans le dossier du package App Installer installé.
- Si nécessaire, SENETECH réenregistre l'`AppxManifest.xml` du package existant au lieu de tenter une rétrogradation.
- La version App Installer déjà installée est conservée.

## V1.6.0.6 DEV — 2026-09-10

- Sur un Windows 10/11 fraîchement installé, SENETECH ne s'arrête plus simplement sur **« WinGet est introuvable »**.
- Ajout du module `Senetech.WinGet.ps1` pour détecter WinGet même lorsque l'alias `WindowsApps` n'est pas encore disponible.
- Si WinGet est réellement absent et qu'Internet est disponible, SENETECH tente automatiquement l'installation/réparation officielle via `Microsoft.WinGet.Client` puis `Repair-WinGetPackageManager`.
- L'installation des applications et la mise à jour des applications réutilisent ensuite le WinGet nouvellement installé.
- En cas d'échec du bootstrap, SENETECH conserve une erreur explicite dans le journal au lieu de masquer le problème.
- Le correctif reste sur `develop` jusqu'à validation sur une installation Windows fraîche.

## V1.6.0.5 DEV — 2026-09-10

- Correction de la régression de relance introduite en build 1.6.0.4.
- **Mode Installé** : retour au mécanisme de relance précédent, qui fonctionnait avant la modification 1.6.0.4.
- **Mode Portable** : relance séparée depuis le propre dossier de SENETECH afin que les fichiers relatifs du runtime soient résolus correctement.
- Suppression du helper PowerShell commun ajouté en 1.6.0.4, qui pouvait perturber Portable et Installé.
- Le téléchargement, la vérification SHA-256, le backup/rollback et l'application de la mise à jour restent inchangés.

## V1.6.0.4 DEV — 2026-09-10

- Tentative de fiabilisation de la relance Portable avec un helper PowerShell et plusieurs tentatives.
- Régression détectée ensuite sur les modes Portable et Installé ; cette mécanique a été retirée en 1.6.0.5.

## V1.6.0.3 DEV — 2026-09-10

- Nouveau module **Livraison / Vente** destiné aux PC préparés pour revente.
- Ajout d'un assistant **FINALISER POUR LA VENTE** distinct du workflow normal de préparation.
- Deux modes de livraison :
  - **PC propre / vierge** : suppression des applications tierces détectées, avec protection automatique des composants Windows, runtimes partagés et pilotes matériels.
  - **PC configuré pour le client** : conservation des applications déjà installées et nettoyage des traces du technicien uniquement.
- Aperçu des applications détectées avant toute suppression.
- Double confirmation avec saisie de `VENTE` avant la phase destructive.
- Nettoyage des fichiers temporaires, éléments récents et traces SENETECH de la session technicien.
- Suppression différée du profil et du compte technicien au prochain démarrage lorsque le compte est supprimable.
- Préparation de Windows pour démarrer sur l'OOBE/Bienvenue sans réinstaller complètement Windows.
- Extinction automatique après finalisation afin que la machine soit prête à être emballée/livrée.
- Nouveau **SENETECH Welcome** au premier profil client : choix d'un profil ou d'applications facultatives, installation via WinGet ou refus avec « Non merci ».
- Le workflow de livraison reste en canal `develop` jusqu'à validation réelle sur une machine de test.

## V1.6.0.2 DEV — 2026-09-10

- Correctif de compatibilité de la fenêtre Démarrage Windows : remplacement du séparateur Unicode problématique par un séparateur ASCII.
- Chargement d'un override dédié après le module technicien pour empêcher le retour du problème d'encodage sous Windows PowerShell 5.1.

## V1.6.0.1 DEV — 2026-09-10

- Correctif d'encodage pour Windows PowerShell 5.1.
- Les fichiers PowerShell du runtime sont normalisés en UTF-8 avec BOM pendant la mise à jour.
- Correction des caractères spéciaux mal affichés dans les fenêtres technicien, notamment le séparateur du gestionnaire de démarrage Windows.

## V1.6.0 DEV — 2026-09-10

Cette version reste exclusivement sur le canal **Développeur (`develop`)** jusqu'à validation.

- Nouveau workflow **PRÉPARER CE PC**.
- Catalogue d'applications dynamique et actualisable à distance.
- Profils dynamiques : Essentiel, Bureautique, Étudiant, Gaming, Créateur, Développement, PC léger, Personnalisé.
- Ajout de Teams, Spotify, Audacity, HandBrake, Blender, GIMP, VS Code, Git, Node.js LTS, Python, Notepad++ et PowerToys au catalogue.
- Installation WinGet avec préférence de langue Windows et fallback éditeur.
- Mise à jour des applications installées via WinGet.
- Création optionnelle d'un point de restauration avant préparation.
- Optimisations Gaming et PC léger limitées, sauvegardées et réversibles.
- Gestion des éléments de démarrage Windows avec restauration des éléments désactivés par SENETECH.
- Nettoyage sécurisé des fichiers temporaires et de la Corbeille.
- Windows Update avancé : logiciels, pilotes et option explicite pour les mises à jour facultatives/Preview.
- Diagnostic enrichi : santé stockage existante, batterie + cycles lorsque disponibles, TPM, Secure Boot, espace du disque système et éléments au démarrage.
- Historique local des opérations.
- Sauvegarde automatique de la version SENETECH précédente avant mise à jour.
- Bouton de rollback vers la version sauvegardée.
- Updater Develop basé sur le package Stable V1.5.1 vérifié par SHA-256 + patch/overlays depuis `develop`.
- Outil de préparation à la signature Authenticode ajouté dans `tools/` ; aucune signature publique n'est appliquée sans certificat de code signing.

## V1.5.1 — Stable

Base Stable publique conservée sur `main` et dans la Release `1.5.1`.
