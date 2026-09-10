# SENETECH Inno Setup installer

Ce dossier contient le script Inno Setup de la version installable de SENETECH.

## Fichier installé

L'application installée conserve toujours le même nom :

`C:\Program Files\SENETECH\SENETECH-Setup.exe`

Le numéro de version appartient à l'installateur téléchargé, pas à l'exécutable installé.

## Build local

1. Installer Inno Setup 6.
2. Depuis la racine du dépôt, assembler le runtime complet :
   `powershell -ExecutionPolicy Bypass -File .\tools\Prepare-SenetechFullPackage.ps1`
3. Compiler :
   `powershell -ExecutionPolicy Bypass -File .\tools\Build-SenetechInstaller.ps1 -Version 1.6.0.26 -Channel develop`

Le résultat est placé dans `dist\installer`.

## Build GitHub

Chaque push sur `develop` déclenche le workflow `Build SENETECH full installer`.
Un tag `dev-vX.Y.Z.W` publie l'installateur DEV dans GitHub Releases.
Les tags Stable seront activés sur `main` seulement après validation de la chaîne DEV.
