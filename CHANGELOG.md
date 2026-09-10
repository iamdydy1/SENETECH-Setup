# Changelog SENETECH Setup — Develop

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
