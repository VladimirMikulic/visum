#!/usr/bin/env bash

RED="\e[31m"
BLUE="\e[34m"
GREEN="\e[32m"
ENDCOLOR_NORMAL="\e[0m"

dependencies=( "curl" "python3" "ssh" )

echo -e "${BLUE}Installing Visum...${ENDCOLOR_NORMAL}"

for dep in "${dependencies[@]}"
do
  which $dep > /dev/null

  if [ $? -ne 0 ]; then
    echo -e "${RED}\"$dep\" is missing. Please install it.${ENDCOLOR_NORMAL}"
    exit 1
  fi
done

echo -e "${GREEN}Dependencies satisfied.${ENDCOLOR_NORMAL}"
sudo rm -rf /usr/share/visum

sudo mkdir /usr/share/visum

install_dir="$(dirname "$0")"

sudo cp -r "./$install_dir/scripts" /usr/share/visum
sudo cp -r "./$install_dir/media" /usr/share/visum
sudo cp "./$install_dir/visum.desktop" /usr/share/applications/visum.desktop

rm -rf ~/.config/visum
mkdir ~/.config/visum

echo 'VISUM_PREFERRED_OFFICE=MICROSOFT_OFFICE' > ~/.config/visum/visum.conf

echo -e "\n${GREEN}Done! Enjoy Visum :)${ENDCOLOR_NORMAL}"