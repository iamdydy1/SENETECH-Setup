# Changelog SENETECH Setup — Develop

## V1.6.0.14 DEV — 2026-09-10

- Ajout d'une **grande vérification automatique du workflow** avant la future promotion en Stable.
- Une **sauvegarde d'état obligatoire** est créée avant chaque préparation dans `C:\ProgramData\SENETECH\Backups`, avec empreinte SHA-256. Si cette sauvegarde ne peut pas être créée, la préparation s'arrête avant les modifications.
- La sauvegarde d'état conserve notamment la liste des applications présentes, des éléments de démarrage, des pilotes signés, du profil choisi et des applications demandées.
- Ajout d'un **préflight automatique** : privilèges administrateur, cohérence du catalogue et des profils, espace disque, disponibilité de WinGet ou du cache USB et présence du moteur Windows Update.
- L'installation principale utilise maintenant le bootstrap WinGet de SENETECH sur les Windows fraîchement installés.
- Avant une installation, SENETECH vérifie si l'application est déjà présente et évite un téléchargement inutile lorsqu'elle est détectée.
- Après chaque installation, SENETECH revérifie réellement l'application. Un simple code de sortie `0` ne suffit plus à déclarer l'installation réussie.
- Le cache USB est renforcé avec taille + SHA-256. L'ancien cache est conservé jusqu'à validation du nouveau téléchargement ; en cas d'échec, l'ancien installateur reste disponible.
- Le moteur Windows Update interprète désormais les résultats Microsoft : **Failed/Aborted** sont bloquants et **SucceededWithErrors** est signalé comme avertissement.
- Ajout d'un **contrôle final global** : applications demandées, sauvegarde d'état, périphériques en erreur, stockage, activation Windows et redémarrage requis.
- Un PC comportant un échec bloquant n'est plus annoncé comme « validé » ; les points à corriger sont affichés et journalisés.
- Ajout de `RELEASE-CHECKLIST.md` pour valider Windows 10, Windows 11, Portable, Installé, cache hors ligne, rollback et Livraison/OOBE avant toute promotion vers `main`.
- La Stable V1.5.1 reste inchangée.

## V1.6.0.13 DEV — 2026-09-10

- Révision générale de l'orthographe, des accents, des accords et de la ponctuation dans les nouveaux écrans V1.6.
- Correction des libellés des outils Technicien, du gestionnaire de démarrage et de l'assistant Livraison/Vente.
- Les profils affichent désormais correctement **Étudiant**, **Créateur**, **Développement**, **PC léger** et **Personnalisé**.
- Les catégories du catalogue utilisent désormais **Multimédia**, **Création** et **Développement**.
- Les textes français de **SENETECH Welcome** ont également été corrigés.
- Les scripts PowerShell concernés restent compatibles avec Windows PowerShell 5.1 : les caractères accentués de l'interface sont générés à l'exécution afin d'éviter le retour du problème d'encodage.
- Les correctifs DisplayName, anti-crash de l'aperçu, responsive et WinGet restent actifs.
- La Stable V1.5.1 reste inchangée.

## V1.6.0.12 DEV — 2026-09-10

- Nouvelle build technique forcée afin de réinjecter le correctif d'inventaire sur les machines déclarant déjà la build 11.
- Le numéro de build technique est désormais visible dans l'interface : **1.6.0 DEV - build 12**.
- Aucun changement n'a été apporté à la Stable V1.5.1.

## V1.6.0.11 DEV — 2026-09-10

- Correction de l'erreur **« La propriété DisplayName est introuvable dans cet objet »** lors de l'ouverture de **Voir les applications détectées**.
- Certaines clés de désinstallation Windows 10 peuvent exister sans propriété `DisplayName` ; SENETECH lit désormais toutes les propriétés du registre de façon défensive via `PSObject.Properties`.
- Les entrées incomplètes sont ignorées proprement au lieu de faire échouer tout l'inventaire.
- La même détection robuste est utilisée pour l'aperçu et pour le nettoyage des applications en mode **PC propre / vierge**.
- Le garde-fou anti-crash de la build 10 reste actif : une erreur d'inventaire ne doit plus fermer SENETECH.
- La Stable V1.5.1 reste inchangée.

## V1.6.0.10 DEV — 2026-09-10

- Correction du crash lorsque le technicien clique sur **Voir les applications détectées** dans l'assistant Livraison/Vente.
- L'ancien `DataGrid` WPF de l'aperçu est remplacé par une liste texte robuste avec scroll horizontal et vertical, plus compatible avec Windows PowerShell 5.1 et les anciens laptops Windows 10.
- Toute erreur lors de l'inventaire ou de l'ouverture de la fenêtre est maintenant interceptée : SENETECH reste ouvert et écrit l'erreur dans le journal.
- L'aperçu continue d'indiquer clairement quelles applications seront **CONSERVÉES** ou **SUPPRIMÉES** en mode PC propre.
- La Stable V1.5.1 reste inchangée.

## V1.6.0.9 DEV — 2026-09-10

- Correction spécifique de la fenêtre **FINALISER POUR LA VENTE** sur les petits écrans et laptops.
- La fenêtre reprend désormais les métriques résolution/DPI du module d'affichage principal.
- Contraste renforcé pour les textes, options, avertissements et informations du profil technicien.
- Taille de police minimale augmentée pour éviter les textes trop petits ou gris illisibles.
- Boutons agrandis et zone de confirmation `VENTE` rendue plus visible.
- Scroll vertical automatique si la hauteur de l'écran ne permet pas d'afficher tout le contenu.
- La fenêtre **Voir les applications détectées** est également rendue responsive.
- La Stable V1.5.1 reste inchangée.

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
