#!/usr/bin/env bash

###############################################################################
# TemPi - Script d'installation avec systemd
# Active le service gettempodays.service fourni dans le dépôt GitHub
###############################################################################

set -euo pipefail

############################
# CONFIGURATION PAR DÉFAUT #
############################

TARGET_USER="pi"
INSTALL_DIR="/home/${TARGET_USER}/TemPi"
WEB_ROOT="/var/www/html"
SERVICE_NAME="gettempodays.service"
SYSTEMD_DIR="/etc/systemd/system"
LOG_FILE="/var/log/tempi-install.log"

####################
# FONCTIONS UTILES #
####################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERREUR: $1"
    exit 1
}

########################
# VÉRIFICATIONS INIT. #
########################

[[ "$EUID" -eq 0 ]] || error_exit "Ce script doit être exécuté en root"

id "$TARGET_USER" &>/dev/null || error_exit "L'utilisateur $TARGET_USER n'existe pas"

log "Installation de TemPi avec systemd pour l'utilisateur $TARGET_USER"

########################
# MISE À JOUR SYSTÈME  #
########################

log "Mise à jour des paquets"
apt update -y && apt upgrade -y

########################
# INSTALLATION PAQUETS #
########################

log "Installation des dépendances"
apt install -y python3 python3-requests apache2 php git

########################
# INSTALLATION PROJET  #
########################

if [[ ! -d "$INSTALL_DIR" ]]; then
    log "Clonage du dépôt TemPi"
    git clone https://github.com/RiftRoar/TemPi.git "$INSTALL_DIR"
    chown -R "$TARGET_USER":"$TARGET_USER" "$INSTALL_DIR"
else
    log "Le dossier TemPi existe déjà, clonage ignoré"
fi

########################
# CONFIGURATION APACHE #
########################

log "Configuration d'Apache"
rm -f "$WEB_ROOT/index.html"
ln -sf "$INSTALL_DIR/index.php" "$WEB_ROOT/index.php"

systemctl enable apache2
systemctl restart apache2

########################
# INSTALLATION SYSTEMD #
########################

SERVICE_SOURCE="$INSTALL_DIR/$SERVICE_NAME"
SERVICE_TARGET="$SYSTEMD_DIR/$SERVICE_NAME"

[[ -f "$SERVICE_SOURCE" ]] || error_exit "Fichier $SERVICE_NAME introuvable dans le dépôt"

log "Installation du service systemd $SERVICE_NAME"
cp "$SERVICE_SOURCE" "$SERVICE_TARGET"

# Sécurité : permissions correctes
chmod 644 "$SERVICE_TARGET"

log "Rechargement de systemd"
systemctl daemon-reexec
systemctl daemon-reload

log "Activation et démarrage du service"
systemctl enable gettempodays
systemctl restart gettempodays

########################
# FIN                 #
########################

log "Installation terminée avec succès 🎉"
log "Statut du service :"
systemctl --no-pager status gettempodays || true

log "Logs en temps réel : journalctl -u gettempodays -f"
