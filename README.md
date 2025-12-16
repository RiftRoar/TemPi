# TemPi
Un système tout en un permettant de configurer une Raspberry comme moniteur des jours Tempo de l'offre EDF

Cette solution est en développement. Elle est testée sur Raspberry Pi 3B

Elle permet de superviser les jours Tempo de l'offre EDF. Elle est prévue pour fonctionner sur un écran branché au Raspberry sur les broche GPIO. Deux carrés seront affichés sur l'écran, celui de gauche aura la couleur de l'offre tempo du jour, et celui de droite aura la couleur de la couleur du jour du lendemain.

Vous devez posséder, une raspberry, un compte sur [RTE-France](https://data.rte-france.com/) ainsi qu'un accès à leur API, un accès internet.

Aucun hardware n'est à installer sur le compteur éléctrique.

## 🚀 Installation

Cette procédure permet d’installer **TemPi** sur un système Linux de type  
**Raspberry Pi OS / Debian**, avec démarrage automatique via **systemd**.

---

### ✅ Prérequis

- Raspberry Pi / machine Linux Debian-like avec écran
- Accès Internet
- Droits `root` (ou `sudo`)
- Un utilisateur existant (par défaut `pi`)
- Python 3
- Apache + PHP (pour l’interface web)

---

### 📦 Étape 1 – Cloner le dépôt

```bash
git clone https://github.com/RiftRoar/TemPi.git
cd TemPi
```
### ⚙️ Étape 2 – Lancer l’installation

Le script d’installation doit être exécuté en root :

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

Le script effectue automatiquement :
- l’installation des dépendances
- la configuration d’Apache
- l’installation du service systemd
- l’activation du service au démarrage

### 🔁 Étape 3 – Vérifier le service systemd

Le service utilisé est : gettempodays.service

Vérifier son statut :
```bash
systemctl status gettempodays
```

Voir les logs en temps réel :
```bash
journalctl -u gettempodays -f
```
### 🌐 Étape 4 – Accéder à l’interface web

Ouvre un navigateur sur le Raspberry Pi ou depuis un autre appareil :
```cpp
http://<adresse-ip-du-pi>/
```

Ou localement :
```cpp
http://localhost
```

| Action          | Commande                              |
| --------------- | ------------------------------------- |
| Démarrer        | `sudo systemctl start gettempodays`   |
| Arrêter         | `sudo systemctl stop gettempodays`    |
| Redémarrer      | `sudo systemctl restart gettempodays` |
| Activer au boot | `sudo systemctl enable gettempodays`  |
| Désactiver      | `sudo systemctl disable gettempodays` |

### 📌 Notes

Le service utilise les données Tempo officielles via l’API RTE
Aucune interaction avec le compteur électrique n’est nécessaire
Le service redémarre automatiquement en cas d’erreur

### 🧹 Désinstallation (manuelle)
```bash
sudo systemctl stop gettempodays
sudo systemctl disable gettempodays
sudo rm /etc/systemd/system/gettempodays.service
sudo systemctl daemon-reload
sudo rm -rf ~/TemPi
```

# Preview

![Example](https://i.imgur.com/cIvg4GI.png)
