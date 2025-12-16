#!/usr/bin/env bash

###############################################################################
# TemPi
###############################################################################

set -euo pipefail

############################
# CONFIGURATION PAR DÉFAUT #
############################

# Utilisateur cible (modifiable via --user)
TARGET_USER="pi"

# Dossier d'installation du projet
INSTALL_DIR="/home/%USER%/TemPi"

# Dossier web
WEB_ROOT="/var/www/html"

# URL locale affichée en kiosk
KIOSK_URL="http://localhost"

# Activer ou non le mode kiosk
ENABLE_KIOSK=true

# Activer ou non Apache/PHP
ENABLE_WEB=true

# Activer ou non la tâche au démarrage
ENABLE_AUTOSTART=true

# Fichier de log global
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#########################
# PARSING DES ARGUMENTS #
#########################

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            TARGET_USER="$2"; shift 2;;
        --no-kiosk)
            ENABLE_KIOSK=false; shift;;
        --no-web)
            ENABLE_WEB=false; shift;;
        --no-autostart)
            ENABLE_AUTOSTART=false; shift;;
        --install-dir)
            INSTALL_DIR="$2"; shift 2;;
        --url)
            KIOSK_URL="$2"; shift 2;;
        -h|--help)
            echo "Options disponibles :"
            echo "  --user <nom>          Utilisateur cible (défaut: pi)"
            echo "  --install-dir <path>  Dossier d'installation"
            echo "  --url <url>           URL affichée en mode kiosk"
            echo "  --no-kiosk            Désactiver le mode kiosk"
            echo "  --no-web              Ne pas installer Apache/PHP"
            echo "  --no-autostart        Ne pas configurer le démarrage automatique"
            exit 0;;
        *)
            error_exit "Option inconnue: $1";;
    esac
Done

INSTALL_DIR="${INSTALL_DIR//%USER%/$TARGET_USER}"

########################
# VÉRIFICATIONS INIT. #
########################

[[ "$EUID" -eq 0 ]] || error_exit "Le script doit être exécuté en root"

id "$TARGET_USER" &>/dev/null || error_exit "L'utilisateur $TARGET_USER n'existe pas"

log "Installation de TemPi pour l'utilisateur $TARGET_USER"

########################
# MISE À JOUR SYSTÈME  #
########################

log "Mise à jour des paquets"
apt update -y && apt upgrade -y

########################
# INSTALLATION PAQUETS #
########################

PACKAGES=(python3 python3-venv git unclutter)

if $ENABLE_WEB; then
    PACKAGES+=(apache2 php)
fi

log "Installation des dépendances: ${PACKAGES[*]}"
apt install -y "${PACKAGES[@]}"

########################
# INSTALLATION PROJET  #
########################

if [[ ! -d "$INSTALL_DIR" ]]; then
    log "Création du dossier $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    chown "$TARGET_USER":"$TARGET_USER" "$INSTALL_DIR"
fi

########################
# CONFIGURATION APACHE #
########################

if $ENABLE_WEB; then
    log "Configuration du serveur web"
    rm -f "$WEB_ROOT/index.html"

    if [[ -f "$INSTALL_DIR/index.php" ]]; then
        ln -sf "$INSTALL_DIR/index.php" "$WEB_ROOT/index.php"
    else
        log "ATTENTION: index.php introuvable dans $INSTALL_DIR"
    fi

    systemctl enable apache2
    systemctl restart apache2
fi

########################
# LOGS UTILISATEUR     #
########################

USER_LOG_DIR="/home/$TARGET_USER/logs"
mkdir -p "$USER_LOG_DIR"
chown "$TARGET_USER":"$TARGET_USER" "$USER_LOG_DIR"

########################
# AUTOSTART SCRIPT    #
########################

if $ENABLE_AUTOSTART; then
    log "Configuration du lancement automatique"
    CRON_CMD="@reboot $INSTALL_DIR/startscript.sh > $USER_LOG_DIR/tempi.log 2>&1"
    crontab -u "$TARGET_USER" -l 2>/dev/null | grep -v tempi || true | \
        { cat; echo "$CRON_CMD"; } | crontab -u "$TARGET_USER" -
fi

########################
# MODE KIOSK (LXDE)   #
########################

if $ENABLE_KIOSK; then
    log "Activation du mode kiosk"
    AUTOSTART_FILE="/etc/xdg/lxsession/LXDE-pi/autostart"

    cat > "$AUTOSTART_FILE" <<EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@xset s off
@xset -dpms
@xset s noblank
@chromium-browser --kiosk --incognito --disable-translate --app=$KIOSK_URL
@unclutter -idle 0
EOF
fi

########################
# FIN                 #
########################

log "Installation terminée avec succès 🎉"
log "Redémarre le système pour finaliser la configuration."
