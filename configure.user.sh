#!/usr/bin/env bash

CUSTOM_ARGUMENTS="no"

WITH_DOTFILE_SYMLINKS="no"
WITH_DOWNLOADS_SYMLINK="no"
WITH_DROPBOX_SYMLINK="no"
WITH_OH_MY_ZSH="no"
WITH_POWERLINE_FONT="no"
WITH_GNOME_FAVORITES="no"
WITH_DOWNLOAD_WALLPAPERS="no"
WITH_RANDOM_WALLPAPER="no"
WITH_THUNDERBIRD="no"
WITH_AUTORUN="no"
WITH_GIT="no"

while [ $# -gt 0 ]; do
    if [ "$1" = "--dotfile-symlinks" ]; then
        WITH_DOTFILE_SYMLINKS="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--downloads-symlink" ]; then
        WITH_DOWNLOADS_SYMLINK="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--dropbox-symlink" ]; then
        WITH_DROPBOX_SYMLINK="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--oh-my-zsh" ]; then
        WITH_OH_MY_ZSH="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--powerline-font" ]; then
        WITH_POWERLINE_FONT="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--gnome-favorites" ]; then
        WITH_GNOME_FAVORITES="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--download-wallpapers" ]; then
        WITH_DOWNLOAD_WALLPAPERS="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--random-wallpaper" ]; then
        WITH_RANDOM_WALLPAPER="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--thunderbird" ]; then
        WITH_THUNDERBIRD="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--autorun" ]; then
        WITH_AUTORUN="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "$1" = "--git" ]; then
        WITH_GIT="yes"
        CUSTOM_ARGUMENTS="yes"
    elif [ "${1:0:2}" = "--" ]; then
        UNKNOWN_ARGUMENTS="${UNKNOWN_ARGUMENTS} $1"
        CUSTOM_ARGUMENTS="yes"
    fi

    shift
done

if [ "${CUSTOM_ARGUMENTS}" = "no" ]; then
    WITH_DOTFILE_SYMLINKS="yes"
    WITH_DOWNLOADS_SYMLINK="yes"
    WITH_DROPBOX_SYMLINK="yes"
    WITH_OH_MY_ZSH="yes"
    WITH_POWERLINE_FONT="yes"
    WITH_GNOME_FAVORITES="yes"
    WITH_DOWNLOAD_WALLPAPERS="yes"
    WITH_RANDOM_WALLPAPER="yes"
    WITH_THUNDERBIRD="yes"
    WITH_AUTORUN="yes"
    WITH_GIT="yes"
fi

function fail {
    if [ $# -eq 0 ]; then
        echo " ERROR"
    else
        echo " $1"
    fi

    exit 1
}

# make symlinks to dotfiles
if [ "${WITH_DOTFILE_SYMLINKS}" = "yes" ]; then
    DOTFILES_PATH="${DATA_PARTITION_MOUNT_PATH}/Profiles"
    DOTFILES=`find "${DOTFILES_PATH}" -maxdepth 1 -name '.*'`

    echo -n "- creating symlinks to dotfiles in ${DOTFILES_PATH}..."

    for DOTFILE in ${DOTFILES}; do
        DOTFILE_BASENAME=`basename "${DOTFILE}"`

        rm -rf "${HOME}/${DOTFILE_BASENAME}"
        ln -s "${DOTFILE}" "${HOME}/"

        if [ $? -ne 0 ]; then
            fail "ln -s '${DOTFILE}' '${HOME}/' failed"
        fi
    done

    echo " ok"
fi

# symlink to Downloads
if [ "${WITH_DOWNLOADS_SYMLINK}" = "yes" ]; then
    echo -n "- creating a symlink to ${DATA_PARTITION_MOUNT_PATH}/Downloads..."
    if rm -df "${HOME}/Downloads"; then
        ln -s "${DATA_PARTITION_MOUNT_PATH}/Downloads" "${HOME}/Downloads"
        echo " ok"
    else
        fail "rm -df '${HOME}/Downloads' failed"
    fi
fi

# symlink to Dropbox folder
if [ "${WITH_DROPBOX_SYMLINK}" = "yes" ]; then
    DROPBOX_PATH="${DATA_PARTITION_MOUNT_PATH}/Dropbox"
    DROPBOX_LINK="${HOME}/Dropbox"

    echo -n "- creating a symlink to Dropbox folder..."
    ln -fs "${DROPBOX_PATH}" "${DROPBOX_LINK}"
    if [ $? -eq 0 ]; then
        echo " ok"
    else
        fail "ln -s failed"
    fi
fi

# install oh-my-zsh
if [ "${WITH_OH_MY_ZSH}" = "yes" ]; then
    echo -n "- installing oh-my-zsh..."
    OH_MY_ZSH_URL="git@github.com:robbyrussell/oh-my-zsh.git"
    OH_MY_ZSH_PATH="${HOME}/.oh-my-zsh"
    rm -rf "${OH_MY_ZSH_PATH}"
    git clone "${OH_MY_ZSH_URL}" "${OH_MY_ZSH_PATH}" >> ${INSTALL_LOGFILE} 2>&1
    cp "${OH_MY_ZSH_PATH}/templates/zshrc.zsh-template" "${HOME}/.zshrc"
    echo " ok"

    # create a theme based on `agnoster` - add job & SHLVL counter
    echo -n "- creating dextero.zsh-theme..."
    BASE_THEME_PATH="${OH_MY_ZSH_PATH}/themes/agnoster.zsh-theme"
    CUSTOMIZED_THEME_PATH="${OH_MY_ZSH_PATH}/themes/dextero.zsh-theme"
    cp "${BASE_THEME_PATH}" "${CUSTOMIZED_THEME_PATH}"
    vim -u NONE -c 'g/$(jobs/norm f$ct]-n "`jobs`" 2f}a%(1j.f"i.)%(2j. %j.)o  [[ $SHLVL -gt 1 ]] && symbols+="%{%F{green}%}u27f2"yypci"$SHLVLZZ' "${CUSTOMIZED_THEME_PATH}"
    echo " ok"

    # customize .zshrc
    echo -n "- customizing .zshrc..."
    # set theme
    vim -u NONE -c 'g/ZSH_THEME=/norm ci"dexteroZZ' "${HOME}/.zshrc"
    # set default user
    echo "DEFAULT_USER=${LOGNAME}" >> ${HOME}/.zshrc
    echo " ok"
fi

# install Powerline-patched fonts
if [ "${WITH_POWERLINE_FONT}" = "yes" ]; then
    echo "- installing Powerline-patched fonts"
    mkdir -p "${HOME}/.fonts"

    echo "   * ubuntu-mono"
    if [ ! -e "${HOME}/.fonts/ubuntu-mono-powerline-ttf" ]; then
        git clone https://github.com/pdf/ubuntu-mono-powerline-ttf.git "${HOME}/.fonts/ubuntu-mono-powerline-ttf" >> ${INSTALL_LOGFILE} 2>&1
    fi

    echo -n "- updating font cache..."
    if fc-cache -vf >> ${INSTALL_LOGFILE} 2>&1 ; then
        echo " ok"
    else
        fail " fc-cache failed"
    fi
fi

# set Gnome favorites
if [ "${WITH_GNOME_FAVORITES}" = "yes" ]; then
    echo -n "- replacing apps in Gnome Favorites bar..."
    gsettings set org.gnome.shell favorite-apps "[ 'gnome-terminal.desktop', 'pidgin.desktop', 'google-chrome.desktop', 'thunderbird.desktop', 'nautilus.desktop', 'skype.desktop', 'spotify.desktop' ]" >> ${INSTALL_LOGFILE} 2>&1
    echo " ok"
fi

# download wallpapers & set random one
if [ "${WITH_DOWNLOAD_WALLPAPERS}" = "yes" ]; then
    echo "- downloading wallpapers"
    WALLPAPERS_DIR="${HOME}/.config/wallpapers"
    WALLPAPERS=" \
        http://i.imgur.com/MoWIQcK.jpg \
        http://i.imgur.com/HKxJDIU.jpg \
        http://i.imgur.com/owJ7NyD.jpg \
        http://i.imgur.com/1ohhqXK.jpg \
        http://i.imgur.com/V2S4f6D.jpg \
    "

    mkdir -p "${WALLPAPERS_DIR}"
    pushd . > /dev/null 2>&1
    cd "${WALLPAPERS_DIR}"
    for URL in ${WALLPAPERS}; do
        echo "   * ${URL}"
        wget -q "${URL}" >> ${INSTALL_LOGFILE} 2>&1
    done
    popd > /dev/null 2>&1
fi

if [ "${WITH_RANDOM_WALLPAPER}" = "yes" ]; then
    RANDOM_WALLPAPER=`ls "${WALLPAPERS_DIR}"/ | sort -R | head -1`
    echo -n "- setting a random wallpaper (${RANDOM_WALLPAPER})..."

    gsettings set org.gnome.desktop.background picture-uri "file:///${WALLPAPERS_DIR}/${RANDOM_WALLPAPER}"
    if [ $? -eq 0 ]; then
        echo " ok"
    else
        fail
    fi
fi

# configure Thunderbird profile
if [ "${WITH_THUNDERBIRD}" = "yes" ]; then
    THUNDERBIRD_CONFIG_PATH="${HOME}/.thunderbird"
    THUNDERBIRD_PROFILE_NAME="${LOGNAME}"
    THUNDERBIRD_PROFILE_SOURCE="${DOTFILES_PATH}/Thunderbird/dex"

    echo -n "- creating a Thunderbird profile..."
    mkdir -p ${THUNDERBIRD_CONFIG_PATH}
    cat > "${THUNDERBIRD_CONFIG_PATH}/profiles.ini" << EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=${THUNDERBIRD_PROFILE_NAME}
IsRelative=1
Path=${THUNDERBIRD_PROFILE_NAME}

EOF
    ln -fs "${THUNDERBIRD_PROFILE_SOURCE}" "${THUNDERBIRD_CONFIG_PATH}/${THUNDERBIRD_PROFILE_NAME}"

    if [ $? -eq 0 ]; then
        echo " ok"
    else
        fail "ln -s failed"
    fi
fi

# add autorun entries
if [ "${WITH_AUTORUN}" = "yes" ]; then
    AUTOSTART_SHORTCUT_SOURCE="/usr/share/applications"
    AUTOSTART_SHORTCUT_DESTINATION="${HOME}/.config/autostart"
    AUTOSTART_ENTRIES=" \
        pidgin \
        thunderbird
    "

    echo "- creating autostart entries"
    mkdir -p "${AUTOSTART_SHORTCUT_DESTINATION}"
    for ENTRY in ${AUTOSTART_ENTRIES}; do
        echo "   * ${ENTRY}"
        cp -f "${AUTOSTART_SHORTCUT_SOURCE}/${ENTRY}.desktop" "${AUTOSTART_SHORTCUT_DESTINATION}/"
    done
fi

# configure git
if [ "${WITH_GIT}" = "yes" ]; then
    echo "- configuring git"
    echo -n "   * enter username: "
    read GIT_USERNAME
    git config --global user.name "${GIT_USERNAME}"

    echo -n "   * enter email address: "
    read GIT_EMAIL
    git config --global user.email "${GIT_EMAIL}"

    echo -n "   * enabling colors..."
    if git config --global color.ui true; then
        echo " ok"
    else
        fail "git config failed"
    fi
fi
