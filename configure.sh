#!/usr/bin/env bash

if [ "${LOGNAME}" != "root" ]; then
    echo "this script should be run as superuser."
    exit 1
fi

if [ $# -gt 0 ]; then
    if [ -e "/home/$1" ]; then
        LOGNAME="$1"
    fi
else
    LOGNAME="dex"
fi

echo ".--------------"
echo "| using login: ${LOGNAME}"
echo "'--------------"

HOME="/home/${LOGNAME}"
INSTALL_LOGFILE="`pwd`/INSTALL.log"

rm -f "${INSTALL_LOGFILE}"
sudo -u ${LOGNAME} touch "${INSTALL_LOGFILE}"

function fail {
    if [ $# -eq 0 ]; then
        echo " ERROR"
    else
        echo " $1"
    fi

    exit 1
}

# add repositories
RELEASE_NAME=`lsb_release -sc`
echo "# adding repositories"

## Dropbox
if [ ! -e /etc/apt/sources.list.d/dropbox.list ]; then
    apt-key adv --keyserver pgp.mit.edu --recv-keys 5044912E >> ${INSTALL_LOGFILE} 2>&1
    echo "deb http://linux.dropbox.com/ubuntu ${RELEASE_NAME} main" > /etc/apt/sources.list.d/dropbox.list
fi

## Final Term
yes | add-apt-repository ppa:finalterm/daily >> ${INSTALL_LOGFILE} 2>&1

## Google
if [ ! -e /etc/apt/sources.list.d/google.list ]; then
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - >> ${INSTALL_LOGFILE} 2>&1
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list
fi

## Skype
if [ ! -e /etc/apt/sources.list.d/canonical_partner.list ]; then
    echo "deb http://archive.canonical.com/ubuntu/ ${RELEASE_NAME} partner" >> /etc/apt/sources.list.d/canonical_partner.list
fi

## Spotify
if [ ! -e /etc/apt/sources.list.d/spotify.list ]; then
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 94558F59 >> ${INSTALL_LOGFILE} 2>&1
    echo "deb http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list
fi

## Vim
yes | add-apt-repository ppa:dgadomski/vim-daily >> ${INSTALL_LOGFILE} 2>&1

echo "# running apt-get update"
apt-get update >> ${INSTALL_LOGFILE} 2>&1

# install essential packages
echo "# installing packages"

PACKAGES=" \
    build-essential \
    clang \
    cmake \
    dropbox \
    finalterm \
    git \
    gnome-shell \
    google-chrome-stable \
    mercurial \
    nvidia-current \
    pidgin \
    powertop \
    python \
    python-dev \
    skype \
    spotify-client \
    subversion \
    thunderbird \
    vim-gtk \
    virtualbox \
    zsh \
"

for PACKAGE in ${PACKAGES}; do
    echo "   * ${PACKAGE}"
    apt-get install -y ${PACKAGE} >> ${INSTALL_LOGFILE} 2>&1
done

# auto-mount data partition
DATA_PARTITION_PATH="/dev/sda2"
DATA_PARTITION_MOUNT_PATH="/media/D"
DATA_PARTITION_FILE_SYSTEM=`blkid ${DATA_PARTITION_PATH} | awk '{ gsub(/^.*TYPE="/, ""); gsub(/".*$/, ""); print }'`

if [ `mount | grep "^${DATA_PARTITION_PATH}" | wc -l` -gt 0 ]; then
    echo "# updating /etc/fstab skipped: ${DATA_PARTITION_PATH} already mounted"
else
    echo -n "# adding ${DATA_PARTITION_PATH} (${DATA_PARTITION_FILE_SYSTEM}, mount at ${DATA_PARTITION_MOUNT_PATH}) to /etc/fstab..."

    mkdir -p ${DATA_PARTITION_MOUNT_PATH}
    echo "${DATA_PARTITION_PATH} ${DATA_PARTITION_MOUNT_PATH} ${DATA_PARTITION_FILE_SYSTEM} errors=remount-ro 0 0" >> /etc/fstab

    if mount -a; then
        echo " ok"
    else
        fail "mount -a failed"
    fi
fi

# set default shell
DEFAULT_SHELL=`which zsh`
echo -n "# setting default shell to ${DEFAULT_SHELL}..."
if chsh --shell "${DEFAULT_SHELL}" "${LOGNAME}"; then
    echo " ok"
else
    fail "chsh '${DEFAULT_SHELL}' failed"
fi

# configure AGH-WPA WiFi network
echo "# configuring AGH-WPA network"
CERT_URL="https://panel.agh.edu.pl/CA-AGH/CA-AGH.der"
CERT_DIR="/etc/ca-certificates"
AGH_WPA_OUTPUT="/etc/NetworkManager/system-connections/AGH-WPA"

echo -n "   * enter username (login@student.agh.edu.pl): "
read AGH_WPA_USERNAME
echo -n "   * enter password: "
read -s AGH_WPA_PASSWORD
echo ""

echo -n "   * retrieving MAC..."
MAC=`ifconfig | grep HWaddr | grep wlan | sed 's/^.*HWaddr //' | sed 's/[ \t]*$//' | tr '[:lower:]' '[:upper:]'`
echo " ${MAC}"

echo -n "   * downloading the certificate to ${CERT_DIR}..."
pushd . > /dev/null 2>&1
cd "${CERT_DIR}"
if [ $? -ne 0 ]; then
    popd > /dev/null 2>&1
    fail "'${CERT_DIR}' does not exist"
fi

wget -q "${CERT_URL}" >> ${INSTALL_LOGFILE} 2>&1
if [ $? -ne 0 ]; then
    popd > /dev/null 2>&1
    fail "wget '${CERT_URL}' failed"
fi

popd > /dev/null 2>&1
echo " ok"

echo -n "   * creating ${AGH_WPA_OUTPUT}..."
cat > "${AGH_WPA_OUTPUT}" << EOF
[ipv6]
method=auto

[connection]
id=AGH-WPA
uuid=ec72efba-ab59-4506-ad8c-26091ce07b0d
type=802-11-wireless

[802-11-wireless]
ssid=AGH-WPA
mode=infrastructure
mac-address=${MAC}
security=802-11-wireless-security

[802-1x]
eap=peap;
identity=${USERNAME}
ca-cert=${CERT_DIR}/CA-AGH.der
phase2-auth=mschapv2
password=${PASSWORD}

[ipv4]
method=auto

[802-11-wireless-security]
key-mgmt=wpa-eap
auth-alg=open
EOF

echo " ok"

# commands that do not require root priveleges are in configure.user.sh
USER_CONFIG_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_CONFIG_SCRIPT="${USER_CONFIG_SCRIPT_DIR}/configure.user.sh"
LOCAL_VARS=""

for VAR in \
    LOGNAME \
    HOME \
    INSTALL_LOGFILE \
    DATA_PARTITION_MOUNT_PATH
do
    LOCAL_VARS="${LOCAL_VARS} ${VAR}=${!VAR}"
done

echo "# executing ${USER_CONFIG_SCRIPT}"
sudo -u ${LOGNAME} ${LOCAL_VARS} /usr/bin/env bash "${USER_CONFIG_SCRIPT}"

