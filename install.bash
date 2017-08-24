#!/bin/bash
$wwwuser = "_www"

if [[ $(whoami) == "root" ]]; then
	echo "ERROR: Do not run this script as root" >> /dev/stderr
	echo "or by using sudo! This will make files" >> /dev/stderr
	echo "created root-only readable and will" >> /dev/stderr
	echo "probably break the installation!" >> /dev/stderr
	echo "Run this as a sudo user instead." >> /dev/stderr
	exit 1
else; if [[ $(sudo -v) != "" ]]; then
	echo "ERROR: You must be an administrator user to run" >> /dev/stderr
	echo "this installation script." >> /dev/stderr
	exit 2
fi;fi
if [[ $(cut -d: -f1 /etc/passwd) | grep "_www") != "" ]]; then
	echo "Looks like you already have a user" >> /dev/stderr
	echo "named '_www' which is the default system" >> /dev/stderr
	echo "user for this installation. Either cancel the" >> /dev/stderr
	echo "program (CTRL-C) and remove it OR change the" >> /dev/stderr
	echo "username used here." >> /dev/stderr
	echo ""
	echo "New username (to make it look system-y start "
	read -r -p "with an underscore. New username: " wwwuser 
fi
sudo -s root <<'EOF'
	printf "Removing stock Lua 5.2..."
	apt-get -yqq purge lua
	echo "done"

	printf "Installing Lua 5.3..."
	apt-get -yqq install lua5.3
	echo "done"

	prinf "Relinking 'lua' command to Lua 5.3..."
	rm -f $(which lua)
	ln -s "$(which lua5.3)" "$(dirname $(which lua5.3))/lua"
	echo "done"

	printf "Installing luarocks..."
	apt-get -yqq install luarocks
	echo "done"

	printf "Installing git..."
	apt-get -yqq install git
	echo "done"

	printf "Installing LuaSocket..."
	luarocks install socket
	echo "done"

	printf "Creating new user for web server..."
	useradd -m -p $(echo "$wwwuser" | openssl passwd -1 -stdin)
	echo "done"

	printf "Switching to that user..."
EOF
sudo -s $wwwuser <<'EOF'
	echo "done"

	printf "Cloning git repo..."
	cd /home/
	rm -rf "./$wwwuser/*"
	git clone https://github.com/WJP2003/eclipse-www-server.git
	mv ./eclipse-www-server/* "./$wwwuser/"
	echo "done"

	printf "Removing install script..."
	rm -f "/home/$wwwuser/install.bash"
	echo "done"

	printf "Switching to root user..."
EOF
sudo -s root <<'EOF'
	echo "done"
	
	printf "Changing ownership of www server directory..."
	chown -R "$wwwuser:nogroup" "/home/$wwwuser"
	echo "done"

	printf "Switching back to www user..."
EOF
sudo -s $wwwuser <<'EOF'
	echo "done"

	printf "Making the web server script executable by only the www user..."
	chmod 774 "/home/$wwwuser/eclipse-www-server.lua"
	echo "done"

	printf "Switching back to root user..."
EOF
sudo -s root <<'EOF'
	echo "done"

	printf "Creating terminal command 'eclipse-www-server'..."
	ln -s "/home/$wwwuser/eclipse-www-server.lua" "/usr/local/bin/eclipse-www-server.lua"
	mv "/home/$wwwuser/eclipse-www-server" "/usr/local/bin/eclipse-www-server"
	mv "/home/$wwwuser/eclipse-www-server.kill" "/usr/local/bin/eclipse-www-server.kill"
	chmod 774 "/usr/local/bin/eclipse-www-server"
	chmod 774 "/usr/local/bin/eclipse-www-server.kill"
	echo "done"

	prinf "Creating systemd service 'eclipse-www-server'..."
	mv "/home/$wwwuser/eclipse-www-server.service" "/lib/systemd/system/eclipse-www-server.service"
	echo "done"
EOF
echo "Installation complete!"
if [[ echo "$wwwuser" != "_www" ]]; then
	echo "NOTE: Since there was a _www already,"
	echo "you must change the 2nd line in"
	echo "/home/$wwwuser/eclipse-www-server.lua"
	echo "from $(cat '/home/$wwwuser/eclipse-www-server.lua' | grep 'server_root' -m 1)"
	echo "to $(cat '/home/$wwwuser/eclipse-www-server.lua' | grep 'server_root' -m -1 | xargs sed -i 's/_www/$wwwuser/g')."
fi
read -s -r -p -t 32768 "Press any key to continue..." -n 1
exit 0
