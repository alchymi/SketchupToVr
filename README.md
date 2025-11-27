# SketchUp → GLB → VR Loader

_Pipeline de publication 3D LMDDC_

Ce projet fournit une chaîne complète permettant d’exporter des scènes SketchUp au format GLB, de les publier via une API sécurisée, puis de les charger dynamiquement dans une application VR Unity (Pico / Quest).

Il est composé de trois éléments principaux :

1. Plugin SketchUp (Ruby) – export en .glb + upload serveur
2. Backend PHP dockerisé – réception et gestion des fichiers
3. Client Unity VR – chargement dynamique et affichage (pour des raison de poids le client unity n'est pas sur ce repo)

L’objectif est de permettre à un utilisateur non technique de publier une scène 3D en VR en quelques secondes.

---

## ✨ Fonctionnalités

- Codes courts uniques (4 caractères)
- Export GLB automatique depuis SketchUp
- API backend :
  - POST /upload_glb.php
  - GET /list_glb.php
- Stockage persistant (volume Docker)
- Manifest JSON mis à jour automatiquement
- Nettoyage automatique des fichiers vieux de 7 jours
- Chargement GLB runtime via glTFast dans Unity

---

## 🧱 Structure du projet

sketchup-glb-api/  
├─ Dockerfile  
├─ docker-compose.yml  
├─ .env  
├─ docker/  
│ └─ php-upload.ini  
├─ php/  
│ ├─ public/  
│ │ ├─ upload_glb.php  
│ │ ├─ list_glb.php  
│ │ └─ uploads_glb/  
│ └─ src/  
│ ├─ helpers.php  
│ └─ config.php  
└─ vr_exporter.rb

---

## 🐳 Backend Docker

Le backend utilise Apache + PHP 8.2 dans un conteneur unique.

**Fichier .env**

BASE_PUBLIC_URL=A remplacer par l'url ou le service est déplouyé
API_KEYS=clé séparé par des virgules ex: jsb-12313,lmd4654645654

les trois premiers caractère servent de filtre à l'app unity pour n'afficher que les upload lié à cette clé

**Volume**

Les fichiers GLB + manifest.json sont stockés dans le volume `sketchup_data`.

---

## 🔐 Sécurité

- Authentification par API Key via l’en-tête HTTP `X-API-KEY`
- Aucun accès public sans clé
- Volume non exposé publiquement
- Suppression automatique des anciens fichiers de plus de 7 jours à chaque nouvel upload

---

## 🧰 Plugin SketchUp

Fonctionnalités du plugin Ruby :

- Export du modèle courant en GLB
- Première exécution : demande URL + API Key
- Stockage dans : %APPDATA%/VRExporter/config.json
- Envoi vers l’API backend
- Affichage du code via popup HTML custom LMDDC

Compatible Windows et macOS.

---

## 🎮 Client Unity VR

Le client Unity :

- interroge GET /list_glb.php
- charge un GLB via glTFast
- affiche le code court
- fonctionne en mode kiosque (Pico / Android)

---

## 🔄 Workflow

1. L’utilisateur exporte → GLB généré
2. Plugin → upload serveur → reçoit un code
3. Manifest.json mis à jour
4. Unity liste les scènes
5. L’utilisateur charge une scène en VR
6. Fichiers > 7 jours supprimés automatiquement

---

## 🧑‍💻 Maintenance

Mise à jour du backend :

docker compose up -d --build

Manifest éditable manuellement si besoin.  
Nettoyage automatique actif.

---

## ✔️ Production-ready

Ce pipeline offre :

- robustesse
- simplicité
- maintenance faible
- accessibilité pour les équipes non techniques
- intégration fluide avec Unity VR

Besoin de la version anglaise, d’un schéma d’architecture ou d’un PDF sysadmin ?  
Demandez-le simplement.
