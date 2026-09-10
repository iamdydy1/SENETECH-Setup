# Changelog SENETECH Setup — Develop

> Ce fichier suit toutes les builds du canal `develop`, y compris les tests, régressions et correctifs. Une modification DEV n'est pas considérée Stable tant qu'elle n'a pas été validée puis promue explicitement sur `main`.

## V1.6.0.18 DEV — 2026-09-10

- Ajout de **SENETECH Reporter** pour le suivi technique à distance.
- Les rapports sont envoyés en HTTPS vers le **Cloudflare Worker SENETECH** ; le webhook Discord reste côté Cloudflare et n'est pas embarqué dans SENETECH.
- **Consentement explicite** au premier lancement avant tout envoi de rapport technique.
- Possibilité de modifier ensuite l'autorisation depuis la section **Rapports techniques**.
- Envoi des événements importants : démarrage SENETECH, installation d'applications, Windows Update, analyse matériel, contrôle final et Livraison/Vente.
- Niveaux de rapport : **SUCCESS**, **INFO**, **WARNING** et **ERROR**.
- Chaque installation reçoit un identifiant aléatoire `SNTPC-...` et chaque événement un identifiant `SNT-...` pour relier les problèmes d'un même poste sans utiliser l'identité du client.
- Les rapports peuvent contenir : version SENETECH, version/build Windows, fabricant/modèle du PC, étape, message technique et court extrait de journal pour les erreurs.
- Filtrage local des informations sensibles : nom d'utilisateur/profil, e-mail, adresse IPv4 et URL de webhook sont masqués avant envoi.
- File d'attente locale limitée lorsque le service de rapport est temporairement indisponible ; nouvelle tentative au prochain lancement.
- Anti-spam : déduplication temporaire des événements identiques.
- Ajout d'un bouton **Tester l'envoi vers SENETECH** pour valider le trajet PC → Cloudflare → Discord.
- Le Reporter ne doit jamais bloquer le fonctionnement principal de SENETECH si Cloudflare/Discord est indisponible.
- Intégration en **overlay tardif** afin d'éviter d'allonger encore la chaîne de patches V1.6.
- **Bug connu à reproduire avec le Reporter :** sur le laptop Windows 10 de test, la build 17 a affiché « Les types des arguments ne correspondent pas » pendant/à la fin de l'analyse matériel. La build 18 doit permettre d'obtenir le contexte technique exact avant correction.
- Stable V1.5.1 inchangée.

## V1.6.0.17 DEV — 2026-09-10

- Correction critique de la mise en forme des chaînes françaises sous Windows PowerShell 5.1.
- Les marqueurs d'accents utilisant des accolades entraient en conflit avec l'opérateur PowerShell/.NET `-f`.
- Normalisation des marqueurs avant chargement de `FrenchUi`, `Validation` et des couches de sécurité.
- La build 17 démarre correctement sur le laptop de test.
- **À investiguer :** erreur « Les types des arguments ne correspondent pas » observée lors de l'analyse matériel.
- Grande vérification, rollback, cache transactionnel et Livraison/OOBE de la build 16 conservés.
- Stable V1.5.1 inchangée.

## V1.6.0.16 DEV — 2026-09-10

- Renforcement de la sécurité avant future promotion Stable.
- Rollback renforcé : validation de la sauvegarde précédente et sauvegarde de sécurité du runtime actuel avant restauration.
- En cas d'échec du rollback, tentative de restauration automatique du runtime courant.
- Cache USB transactionnel : l'ancien cache reste intact jusqu'à validation complète du nouveau fichier.
- Protection de SENETECH Setup contre une suppression accidentelle pendant le mode **PC propre / vierge**.
- Nettoyage des traces technicien et des sauvegardes/validations lors de la finalisation Vente.
- Mode PC configuré : mémorisation des applications préparées et nouvelle vérification sur le profil du client.
- SENETECH Welcome vérifie les applications déjà présentes, n'installe que les manquantes et contrôle le résultat de chaque installation.
- Stable V1.5.1 inchangée.

## V1.6.0.15 DEV — 2026-09-10

- Correctif critique de démarrage après la régression introduite par la correction française de la build 13.
- Cause identifiée : PowerShell traite les clés de hashtable sans distinction de casse ; certains marqueurs d'accents majuscules/minuscules étaient donc considérés comme des doublons.
- Les marqueurs majuscules utilisent désormais des noms uniques.
- SENETECH peut de nouveau ouvrir son interface ; d'autres conflits de formatage ont ensuite été détectés et corrigés en build 17.
- Stable V1.5.1 inchangée.

## V1.6.0.14 DEV — 2026-09-10

- Ajout d'une **grande vérification automatique du workflow** avant la future promotion en Stable.
- Une **sauvegarde d'état obligatoire** est créée avant chaque préparation dans `C:\ProgramData\SENETECH\Backups`, avec empreinte SHA-256. Si cette sauvegarde ne peut pas être créée, la préparation s'arrête avant les modifications.
- La sauvegarde conserve notamment la liste des applications présentes, des éléments de démarrage, des pilotes signés, du profil choisi et des applications demandées.
- Préflight automatique : privilèges administrateur, cohérence du catalogue/profils, espace disque, disponibilité WinGet ou cache USB et présence du moteur Windows Update.
- L'installation principale utilise le bootstrap WinGet SENETECH sur les Windows fraîchement installés.
- Avant installation, SENETECH vérifie si l'application est déjà présente et évite un téléchargement inutile.
- Après installation, l'application doit être réellement retrouvée. Un simple code de sortie `0` ne suffit plus à déclarer une installation réussie.
- Cache USB renforcé avec taille + SHA-256 ; l'ancien cache reste disponible jusqu'à validation du nouveau.
- Windows Update interprète **Failed/Aborted** comme bloquants et signale **SucceededWithErrors**.
- Contrôle final global : applications demandées, sauvegarde d'état, périphériques en erreur, stockage, activation Windows et redémarrage requis.
- Un PC avec un échec bloquant n'est plus annoncé comme validé.
- Ajout de `RELEASE-CHECKLIST.md` pour Windows 10/11, Portable/Installé, cache hors ligne, rollback et Livraison/OOBE.
- Stable V1.5.1 inchangée.

## V1.6.0.13 DEV — 2026-09-10

- Révision générale de l'orthographe, des accents, des accords et de la ponctuation dans les nouveaux écrans V1.6.
- Correction des libellés Technicien, Démarrage Windows et Livraison/Vente.
- Profils corrigés : **Étudiant**, **Créateur**, **Développement**, **PC léger**, **Personnalisé**.
- Catégories corrigées : **Multimédia**, **Création**, **Développement**.
- Textes SENETECH Welcome corrigés.
- Cette build a révélé une incompatibilité de certains marqueurs d'accents avec Windows PowerShell 5.1, corrigée ensuite en builds 15 et 17.

## V1.6.0.12 DEV — 2026-09-10

- Build technique forcée pour réinjecter le correctif d'inventaire sur les machines déclarant déjà la build 11.
- Numéro de build technique rendu visible dans l'interface.

## V1.6.0.11 DEV — 2026-09-10

- Correction de « La propriété DisplayName est introuvable dans cet objet » dans **Voir les applications détectées**.
- Lecture défensive des propriétés registre via `PSObject.Properties`.
- Les entrées de désinstallation incomplètes sont ignorées proprement.
- Même inventaire robuste utilisé pour l'aperçu et le nettoyage **PC propre / vierge**.

## V1.6.0.10 DEV — 2026-09-10

- Correction du crash de **Voir les applications détectées**.
- Remplacement du DataGrid WPF par une liste texte robuste avec scroll horizontal/vertical.
- Les erreurs d'inventaire sont interceptées et journalisées sans fermer SENETECH.

## V1.6.0.9 DEV — 2026-09-10

- Fenêtre **FINALISER POUR LA VENTE** adaptée aux petits écrans/laptops.
- Contraste renforcé, police agrandie, boutons adaptés et scroll vertical.
- Aperçu des applications rendu responsive.

## V1.6.0.8 DEV — 2026-09-10

- Ajout de `Senetech.Display.ps1` pour adapter automatiquement la fenêtre à la résolution et au DPI Windows.
- Mode Compact pour les petits écrans, notamment 1366×768.
- WPF conserve la gestion DPI native ; SENETECH ne modifie pas la résolution Windows.
- **Validé sur le laptop de test :** la fenêtre principale est correctement dimensionnée.

## V1.6.0.7 DEV — 2026-09-10

- Correction du cas Windows 10 où Desktop App Installer est déjà installé mais où `winget.exe` n'est pas résolu par l'alias WindowsApps.
- Recherche directe de WinGet dans le package App Installer et réenregistrement du manifeste si nécessaire.
- Pas de rétrogradation d'une version App Installer déjà plus récente.

## V1.6.0.6 DEV — 2026-09-10

- Bootstrap/réparation automatique de WinGet via `Microsoft.WinGet.Client` sur Windows fraîchement installé.
- Réutilisation du WinGet réparé par l'installation et la mise à jour des applications.
- Erreur explicite dans le journal si la réparation échoue.

## V1.6.0.5 DEV — 2026-09-10

- Correction de la régression de relance introduite en build 1.6.0.4.
- Mode Installé : retour au mécanisme de relance précédent.
- Mode Portable : relance séparée depuis le propre dossier SENETECH.
- Téléchargement, SHA-256, backup/rollback inchangés.

## V1.6.0.4 DEV — 2026-09-10

- Tentative de fiabilisation de la relance Portable avec un helper commun.
- Régression détectée sur Portable et Installé ; retirée en build 5.

## V1.6.0.3 DEV — 2026-09-10

- Ajout du module **Livraison / Vente**.
- Deux modes : **PC propre / vierge** et **PC configuré pour le client**.
- Aperçu des applications avant suppression et double confirmation `VENTE`.
- Nettoyage des traces technicien, suppression différée du profil, préparation OOBE et extinction automatique.
- Ajout de **SENETECH Welcome** au premier profil client.

## V1.6.0.2 DEV — 2026-09-10

- Correctif de compatibilité de la fenêtre Démarrage Windows.
- Remplacement du séparateur Unicode problématique par un séparateur ASCII.

## V1.6.0.1 DEV — 2026-09-10

- Normalisation UTF-8/BOM des scripts concernés pour Windows PowerShell 5.1.
- Correction des caractères spéciaux mal affichés dans les fenêtres technicien.

## V1.6.0 DEV — 2026-09-10

Cette version reste exclusivement sur le canal **Développeur (`develop`)** jusqu'à validation complète.

- Nouveau workflow **PRÉPARER CE PC**.
- Catalogue d'applications et profils dynamiques.
- Profils : Essentiel, Bureautique, Étudiant, Gaming, Créateur, Développement, PC léger, Personnalisé.
- Installation/mise à jour d'applications via WinGet, langue Windows avec fallback éditeur.
- Point de restauration optionnel, optimisations réversibles et gestion du démarrage Windows.
- Nettoyage sécurisé, Windows Update avancé, diagnostic enrichi et historique local.
- Backup/rollback SENETECH.
- Updater Develop basé sur la Stable V1.5.1 vérifiée SHA-256 + patches/overlays.
- Outil de préparation à la signature Authenticode ; aucun certificat public encore appliqué.

## V1.5.1 — Stable

Base Stable publique conservée sur `main` et dans la Release `1.5.1`.
