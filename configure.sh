#!/usr/bin/env bash

if [ "${LOGNAME}" != "root" ]; then
    echo "this script should be run as superuser."
    exit 1
fi

# arguments
ALL_ARGUMENTS=$@
CUSTOM_ARGUMENTS="no"

WITH_ADD_REPOSITORIES="no"
WITH_INSTALL_PACKAGES="no"
WITH_CONFIGURE_MOUNT="no"
WITH_SET_SHELL="no"
WITH_CONFIGURE_AGH_WPA="no"
WITH_INSTALL_PYCLEWN="no"

LOGNAME=""

while [ $# -gt 0 ]; do
    if [ -e "/home/$1" ]; then
        LOGNAME="$1"
    elif [ "$1" = "--add-repositories" ]; then
        WITH_ADD_REPOSITORIES="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--install-packages" ]; then
        WITH_INSTALL_PACKAGES="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--configure-mount" ]; then
        WITH_CONFIGURE_MOUNT="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--set-shell" ]; then
        WITH_SET_SHELL="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--configure-agh-wpa" ]; then
        WITH_CONFIGURE_AGH_WPA="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--install-pyclewn" ]; then
        WITH_INSTALL_PYCLEWN="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "${1:0:2}" = "--" ]; then
        CUSTOM_ARGUMENTS="yes"
    fi

    shift
done

if [ -z "${LOGNAME}" ]; then
    LOGNAME="dex"
fi

if [ "${CUSTOM_ARGUMENTS}" = "no" ]; then
    WITH_ADD_REPOSITORIES="yes"
    WITH_INSTALL_PACKAGES="yes"
    WITH_CONFIGURE_MOUNT="yes"
    WITH_SET_SHELL="yes"
    WITH_CONFIGURE_AGH_WPA="yes"
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
if [ "${WITH_ADD_REPOSITORIES}" = "yes" ]; then
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

    ## Oracle Java
    yes | add-apt-repository ppa:webupd8team/java >> ${INSTALL_LOGFILE} 2>&1

    echo "# running apt-get update"
    apt-get update >> ${INSTALL_LOGFILE} 2>&1
fi

# install essential packages
if [ "${WITH_INSTALL_PACKAGES}" = "yes" ]; then
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
        python3 \
        python-dev \
        skype \
        spotify-client \
        subversion \
        thunderbird \
        valgrind \
        vim-gtk \
        virtualbox \
        zsh \
    "

    for PACKAGE in ${PACKAGES}; do
        echo "   * ${PACKAGE}"
        apt-get install -y ${PACKAGE} >> ${INSTALL_LOGFILE} 2>&1
    done
fi

# auto-mount data partition
if [ "${WITH_CONFIGURE_MOUNT}" = "yes" ]; then
    echo -n "   * enter data partition path (/dev/sdXN): "
    read DATA_PARTITION_PATH
    echo -n "   * enter data partition mount point: "
    read DATA_PARTITION_MOUNT_PATH

    DATA_PARTITION_FILE_SYSTEM=`blkid ${DATA_PARTITION_PATH} | awk '{ gsub(/^.*TYPE="/, ""); gsub(/".*$/, ""); print }'`

    if [ `mount | grep "^${DATA_PARTITION_PATH}" | wc -l` -gt 0 ]; then
        echo "# updating /etc/fstab skipped: ${DATA_PARTITION_PATH} already mounted"
    else
        echo -n "# adding ${DATA_PARTITION_PATH} (${DATA_PARTITION_FILE_SYSTEM}, mount at ${DATA_PARTITION_MOUNT_PATH}) to /etc/fstab..."

        mkdir -p ${DATA_PARTITION_MOUNT_PATH}
        echo "${DATA_PARTITION_PATH} ${DATA_PARTITION_MOUNT_PATH} ${DATA_PARTITION_FILE_SYSTEM} uid=$(id -u "${LOGNAME}"),gid=$(id -g "${LOGNAME}"),errors=remount-ro 0 0" >> /etc/fstab

        if mount -a; then
            echo " ok"
        else
            fail "mount -a failed"
        fi
    fi
fi

# set default shell
if [ "${WITH_SET_SHELL}" = "yes" ]; then
    DEFAULT_SHELL=`which zsh`
    echo -n "# setting default shell to ${DEFAULT_SHELL}..."
    if chsh --shell "${DEFAULT_SHELL}" "${LOGNAME}"; then
        echo " ok"
    else
        fail "chsh '${DEFAULT_SHELL}' failed"
    fi
fi

# configure AGH-WPA WiFi network
if [ "${WITH_CONFIGURE_AGH_WPA}" = "yes" ]; then
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

    rm -f "${CERT_DIR}/CA-AGH.der"
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
identity=${AGH_WPA_USERNAME}
ca-cert=${CERT_DIR}/CA-AGH.der
phase2-auth=mschapv2
password=${AGH_WPA_PASSWORD}
system-ca-certs=true

[ipv4]
method=auto

[802-11-wireless-security]
key-mgmt=wpa-eap
auth-alg=open
EOF

    chmod 600 "${AGH_WPA_OUTPUT}"
    echo " ok"
fi

if [ "${WITH_INSTALL_PYCLEWN}" = "yes" ]; then
    echo "# configuring PyClewn"

    pushd . > /dev/null 2>&1

    VUNDLE_ROOT="${HOME}/.vim/bundle"
    PYCLEWN_DIR_NAME="pyclewn"
    mkdir -p ${VUNDLE_ROOT}
    cd ${VUNDLE_ROOT}

    echo -n "   * cloning git repository... "
    if git clone "http://github.com/lrem/pyclewn" "${PYCLEWN_DIR_NAME}" >> ${INSTALL_LOGFILE} 2>&1 ; then
        echo "ok"

        cd "${VUNDLE_ROOT}/${PYCLEWN_DIR_NAME}"

        echo -n "   * setting up macro files... "
        cd "runtime"
        cp ".pyclewn_keys.template" ".pyclewn_keys.simple"
        cp ".pyclewn_keys.template" ".pyclewn_keys.gdb"
        cp ".pyclewn_keys.template" ".pyclewn_keys.pdb"
        cd ..
        echo "ok"

        echo -n "   * installing pyclewn... "
        if python3 setup.py install --force >> ${INSTALL_LOGFILE} 2>&1 ; then
            echo "ok"
        else
            echo "error!"
        fi
    else
        echo "error!"
    fi

    popd . > /dev/null 2>&1
fi

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
sudo -u ${LOGNAME} ${LOCAL_VARS} /usr/bin/env bash "${USER_CONFIG_SCRIPT}" "${ALL_ARGUMENTS}"

