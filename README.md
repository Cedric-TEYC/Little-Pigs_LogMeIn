![CI/CD](https://github.com/cedricteyc/Little-Pigs_LogMeIn/actions/workflows/docker-publish.yml/badge.svg)
[![DockerHub Backend](https://img.shields.io/docker/v/cedricteyc/littlepigs-backend?label=backend)](https://hub.docker.com/r/cedricteyc/littlepigs-backend)
[![DockerHub Frontend](https://img.shields.io/docker/v/cedricteyc/littlepigs-frontend?label=frontend)](https://hub.docker.com/r/cedricteyc/littlepigs-frontend)

# Little-Pigs_LogMeIn

## Présentation

Little-Pigs_LogMeIn est une application web qui permet d’afficher, centraliser et gérer les logs d’un système via un dashboard simple et moderne.
Le projet utilise Docker pour tout lancer facilement, sans configuration complexe.

![Negan Little Pig](./negan-the-walking-dead.gif)
---

## Prérequis

- Docker Desktop installé sur votre machine (Windows, Mac ou Linux)

---

## Installation & Lancement rapide

1. Cloner ce dépôt :
   git clone https://github.com/Cedric-TEYC/Little-Pigs_LogMeIn.git
   cd Little-Pigs_LogMeIn

2. Lancer l’application avec Docker Compose :
   docker compose up --build

3. Ouvrir l’application :
   Aller sur http://localhost:3000 dans votre navigateur.

---

## Utilisation

- Dashboard : Affiche la liste des logs enregistrés (message, niveau, date)
- Afficher logs détaillés : Permet d’afficher les informations avancées pour chaque log (IP, géolocalisation, User Agent)
- Bouton “Vider logs” : Supprime tous les logs de la base
- Bouton “Test log” : Ajoute un log de test pour la démo

Tout fonctionne directement dès que Docker a démarré les conteneurs.

---

## Structure du projet

- backend/ : API Flask pour gérer et stocker les logs
- frontend/ : Interface HTML/CSS/JS du dashboard
- nginx/ : Reverse proxy pour servir le frontend et relayer vers l’API
- docker-compose.yml : Orchestration de l’ensemble

---

## Pour arrêter l’application

Dans le dossier du projet :
   docker compose down

---

## Création

Ce site a été conçu et développé par **Axis Architecture**.

---

## Questions ou support

Contact : contact.axis.architecture@gmail.com

---

## Création

Ce site a été conçu et développé par **Axis Architecture**.

---

