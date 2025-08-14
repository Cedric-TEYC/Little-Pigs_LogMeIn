![CI/CD](https://github.com/cedricteyc/Little-Pigs_LogMeIn/actions/workflows/docker-publish.yml/badge.svg)  
[![DockerHub Backend](https://img.shields.io/docker/v/cedricteyc/littlepigs-backend?label=backend)](https://hub.docker.com/r/cedricteyc/littlepigs-backend)  
[![DockerHub Frontend](https://img.shields.io/docker/v/cedricteyc/littlepigs-frontend?label=frontend)](https://hub.docker.com/r/cedricteyc/littlepigs-frontend)  

# Little-Pigs_LogMeIn  

## 🐷 Présentation  
**Little-Pigs_LogMeIn** est une application web permettant de centraliser, afficher et gérer les logs système via un dashboard moderne, clair et intuitif.  
Pensée pour être rapide à déployer et sécurisée par défaut, elle repose sur une architecture **Docker** (Backend Flask + Frontend HTML/JS + Nginx + PostgreSQL).  

Chaque mise à jour du code passe par un pipeline **CI/CD DevSecOps** qui :  
- Lance des tests automatisés (Pytest)  
- Analyse la qualité et la sécurité du code (Bandit, Flake8)  
- Scanne le projet à la recherche de vulnérabilités, secrets et configurations à risque (Trivy)  
- Construit et scanne les images Docker  
- Ne déploie que si **tous les contrôles sont validés**   

![Negan Little Pig](./negan-the-walking-dead.gif)  

---

## ⚡ Fonctionnalités principales  
- Dashboard temps réel : logs avec message, niveau, date  
- Détails enrichis : IP, géolocalisation, User Agent  
- Gestion simplifiée : bouton “Vider logs” pour nettoyer la base  
- Ajout de logs de test pour démonstration  
- API REST intégrable à d’autres systèmes  

---

## 📡 Accès API  
| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/logs` | GET | Récupère tous les logs au format JSON |
| `/api/logs?html=1` | GET | Récupère les logs au format HTML |
| `/api/logs/clear` | DELETE | Supprime tous les logs |
| `/api/stats` | GET | Affiche des statistiques sur les logs |
| `/api/health` | GET | Vérifie l’état de santé de l’application |

**Exemples en local** :  
- http://localhost:3000/api/logs  
- http://localhost:3000/api/logs?html=1  
- http://localhost:3000/api/stats  
- http://localhost:3000/api/health  

---

## Installation rapide  
1. Cloner le dépôt :  
git clone https://github.com/Cedric-TEYC/Little-Pigs_LogMeIn.git  
cd Little-Pigs_LogMeIn  

2. Lancer avec Docker Compose :  
docker compose up --build  

3. Accéder au dashboard :  
http://localhost:3000  

---

## Architecture  
- **backend/** → API Flask (gestion/stocks logs)  
- **frontend/** → Interface utilisateur HTML/CSS/JS  
- **nginx/** → Reverse proxy + routage  
- **docker-compose.yml** → Orchestration complète  

---

## Pipeline DevSecOps  
Chaque push déclenche automatiquement :  
1. Tests avec Pytest  
2. Analyse code (Bandit, Flake8)  
3. Scan vulnérabilités & secrets (Trivy)  
4. Build & scan images Docker  
5. Push images vers Docker Hub seulement si tout est OK  
6. Déploiement automatisé sur le cluster Docker Swarm  

---

## Arrêt de l’application  
Depuis le dossier du projet :  
docker compose down  

---

## Déploiement automatique sur cluster  
Le déploiement est entièrement automatisé via `deploy-cluster.sh` exécuté par le pipeline GitHub Actions.  
Ce script :  
- Met à jour la configuration du cluster (les machines a integrer dans le cluster sont renseignées içi `cluster_config.yml`)
- Relance les services avec les nouvelles images validées  
- Exécute un healthcheck (`healthcheck.sh`) pour confirmer que tout fonctionne  
- Génère un rapport d’état détaillé du cluster  

---

## Support  
Contact : **contact.axis.architecture@gmail.com**  
