#------ SUBLIME TEXT
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null
echo -e 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc' | sudo tee /etc/apt/sources.list.d/sublime-text.sources
#------ APT
sudo apt update
sudo apt install -y golang docker-compose docker.io xsel sublime-text bloodhound-ce-python seclists fzf peass bat bloodyad enum4linux-ng evil-winrm-py penelope eza zsh-autosuggestions grc sudo colorize zsh-syntax-highlighting
#------ GO
go install github.com/ropnop/kerbrute
git clone https://github.com/Macmod/godap
cd godap
go install .
cd
#------ OhMyZSH
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#------ Home
chmod +x kskew.sh panel-tcp-listeners.sh
mv kskew.sh .tmux.conf .zshrc ~/
mkdir ~/Scripts
rmdir ~/Music ~/Projects ~/Public ~/Templates ~/Videos
mv panel-tcp-listeners.sh ~/Scripts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Hack.zip
sudo unzip Hack.zip -d /usr/share/fonts/Hack
rm Hack.zip
export PATH=$PATH:/home/kali/go/bin
#------ BloodHound
wget https://github.com/SpecterOps/bloodhound-cli/releases/download/v0.2.1/bloodhound-cli-linux-amd64.tar.gz
tar xfvz bloodhound-cli-linux-amd64.tar.gz
rm bloodhound-cli-linux-amd64.tar.gz
sudo mkdir -p ~/.config/bloodhound
sudo echo 'BLOODHOUND_PORT=8888' >  ~/.config/bloodhound/.env
sudo mv bloodhound-cli /usr/bin
sudo bloodhound-cli install
