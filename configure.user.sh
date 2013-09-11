#!/usr/bin/env bash

function fail {
    if [ $# -eq 0 ]; then
        echo " ERROR"
    else
        echo " $1"
    fi

    exit 1
}

# make symlinks to dotfiles
DOTFILES_PATH="${DATA_PARTITION_MOUNT_PATH}/Profiles"
DOTFILES=`find "${DOTFILES_PATH}" -maxdepth 1 -name '.*'`

echo -n "- Creating symlinks to dotfiles in ${DOTFILES_PATH}..."

for DOTFILE in ${DOTFILES}; do
    DOTFILE_BASENAME=`basename "${DOTFILE}"`

    rm -rf "${HOME}/${DOTFILE_BASENAME}"
    ln -s "${DOTFILE}" "${HOME}/"

    if [ $? -ne 0 ]; then
        fail "ln -s '${DOTFILE}' '${HOME}/' failed"
    fi
done

echo " ok"

# symlink to Downloads
echo -n "- Creating a symlink to ${DATA_PARTITION_MOUNT_PATH}/Downloads..."
if rm -df "${HOME}/Downloads"; then
    ln -s "${DATA_PARTITION_MOUNT_PATH}/Downloads" "${HOME}/Downloads"
    echo " ok"
else
    fail "rm -df '${HOME}/Downloads' failed"
fi

# install oh-my-zsh
echo -n "- Installing oh-my-zsh..."
OH_MY_ZSH_URL="git://github.com/robbyrussell/oh-my-zsh.git"
OH_MY_ZSH_PATH="${HOME}/.oh-my-zsh"
rm -rf "${OH_MY_ZSH_PATH}"
git clone ${OH_MY_ZSH_URL} ${OH_MY_ZSH_PATH} >> ${INSTALL_LOGFILE} 2>&1
cp "${OH_MY_ZSH_PATH}/templates/zshrc.zsh-template" "${HOME}/.zshrc"
echo " ok"

# create a theme based on `agnoster` - add job & SHLVL counter
echo -n "- Creating dextero.zsh-theme..."
BASE_THEME_PATH="${OH_MY_ZSH_PATH}/themes/agnoster.zsh-theme"
CUSTOMIZED_THEME_PATH="${OH_MY_ZSH_PATH}/themes/dextero.zsh-theme"
cp "${BASE_THEME_PATH}" "${CUSTOMIZED_THEME_PATH}"
vim -u NONE -c 'g/$(jobs/norm f$cf)$NUM_JOBSO  NUM_JOBS=pjyypci"$NUM_JOBSykP2jVj:s/NUM_JOBS/SHLVL/gk2f{ciBgreen2f}lsu27f2ZZ' "${CUSTOMIZED_THEME_PATH}"
echo " ok"

# customize .zshrc
echo -n "- Customizing .zshrc..."
# set theme to 'agnoster'
vim -u NONE -c 'g/ZSH_THEME=/norm ci"dexteroZZ' "${HOME}/.zshrc"
# set default user
echo "DEFAULT_USER=${LOGNAME}" >> ${HOME}/.zshrc
echo " ok"

# install Powerline-patched fonts
echo "- Installing Powerline-patched fonts"
mkdir -p "${HOME}/.fonts"

echo "   * ubuntu-mono"
if [ ! -e "${HOME}/.fonts/ubuntu-mono-powerline-ttf" ]; then
    git clone https://github.com/pdf/ubuntu-mono-powerline-ttf.git "${HOME}/.fonts/ubuntu-mono-powerline-ttf" >> ${INSTALL_LOGFILE} 2>&1
fi

echo -n "- Updating font cache..."
if fc-cache -vf >> ${INSTALL_LOGFILE} 2>&1 ; then
    echo " ok"
else
    fail " fc-cache failed"
fi

# set Gnome favorites
echo -n "- Replacing apps in Gnome Favorites bar..."
gsettings set org.gnome.shell favorite-apps "[ 'gnome-terminal.desktop', 'pidgin.desktop', 'google-chrome.desktop', 'thunderbird.desktop', 'nautilus.desktop', 'skype.desktop', 'spotify.desktop' ]" >> ${INSTALL_LOGFILE} 2>&1
echo " ok"

# download wallpapers & set random one
echo "- Downloading wallpapers"
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

RANDOM_WALLPAPER=`ls "${WALLPAPERS_DIR}"/ | sort -R | head -1`
echo -n "- Setting a random wallpaper (${RANDOM_WALLPAPER})..."

gsettings set org.gnome.desktop.background picture-uri "file:///${WALLPAPERS_DIR}/${RANDOM_WALLPAPER}"
if [ $? -eq 0 ]; then
    echo " ok"
else
    fail
fi

# configure Thunderbird profile
THUNDERBIRD_CONFIG_PATH="${HOME}/.thunderbird"
THUNDERBIRD_PROFILE_NAME="${LOGNAME}"
THUNDERBIRD_PROFILE_SOURCE="${DOTFILES_PATH}/Thunderbird/dex"

echo -n "- Creating a Thunderbird profile..."
mkdir -p ${THUNDERBIRD_CONFIG_PATH}
cat > "${THUNDERBIRD_CONFIG_PATH}/profiles.ini" << EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=${THUNDERBIRD_PROFILE_NAME}
IsRelative=1
Path=${THUNDERBIRD_PROFILE_NAME}

EOF
ln -s "${THUNDERBIRD_PROFILE_SOURCE}" "${THUNDERBIRD_CONFIG_PATH}/${THUNDERBIRD_PROFILE_NAME}"

if [ $? -eq 0 ]; then
    echo " ok"
else
    fail "ln -s failed"
fi

# add autorun entries
AUTOSTART_SHORTCUT_SOURCE="/usr/share/applications"
AUTOSTART_SHORTCUT_DESTINATION="${HOME}/.config/autostart"
AUTOSTART_ENTRIES=" \
    pidgin \
    thunderbird
"

echo "- Creating autostart entries"
for ENTRY in ${AUTOSTART_ENTRIES}; do
    echo "   * ${ENTRY}"
    cp -f "${AUTOSTART_SHORTCUT_SOURCE}/${ENTRY}.desktop" "${AUTOSTART_SHORTCUT_DESTINATION}/"
done

