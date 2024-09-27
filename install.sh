#!/bin/bash

set -e  # Stop on error

echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

echo "Installation des dépendances requises..."
sudo apt install -y curl sqlite3

# Création de l'utilisateur radarr et du groupe media
echo "Création de l'utilisateur radarr et du groupe media..."
sudo groupadd media || echo "Le groupe media existe déjà."
sudo useradd -r -s /bin/false -g media radarr || echo "L'utilisateur radarr existe déjà."

# Création du répertoire de données
echo "Création du répertoire de données /var/lib/radarr..."
sudo mkdir -p /var/lib/radarr
sudo chown radarr:media /var/lib/radarr
sudo chmod 775 /var/lib/radarr

# Téléchargement de Radarr
echo "Téléchargement de Radarr..."
ARCH=$(dpkg --print-architecture)

if [[ "$ARCH" == "amd64" ]]; then
    ARCH_TYPE="x64"
elif [[ "$ARCH" == "armhf" || "$ARCH" == "armel" ]]; then
    ARCH_TYPE="arm"
elif [[ "$ARCH" == "arm64" ]]; then
    ARCH_TYPE="arm64"
else
    echo "Architecture non supportée : $ARCH"
    exit 1
fi

wget --content-disposition "http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${ARCH_TYPE}"

# Décompression des fichiers
echo "Décompression des fichiers..."
tar -xvzf Radarr*.linux*.tar.gz

# Déplacement des fichiers vers /opt/
echo "Déplacement des fichiers vers /opt..."
sudo mv Radarr /opt/

# Configuration des permissions
echo "Configuration des permissions pour le binaire Radarr..."
sudo chown -R radarr:media /opt/Radarr

# Création du fichier de service pour systemd
echo "Création du service systemd pour Radarr..."
cat << EOF | sudo tee /etc/systemd/system/radarr.service > /dev/null
[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
User=radarr
Group=media
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Recharger systemd
echo "Rechargement de systemd..."
sudo systemctl daemon-reload

# Activer et démarrer le service Radarr
echo "Activation et démarrage du service Radarr..."
sudo systemctl enable --now radarr

# (Optionnel) Suppression de l'archive tarball
echo "Suppression de l'archive tarball..."
rm Radarr*.linux*.tar.gz

# Vérification du statut du service
echo "Vérification du statut de Radarr..."
sudo systemctl status radarr

echo "Installation terminée ! Vous pouvez accéder à Radarr via http://{Votre_IP}:7878."
