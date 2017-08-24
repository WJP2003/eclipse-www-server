#!/bin/bash

if [[ "$1" != "" ]]; then
	wwwuser="$1"
else
	wwwuser="_www"
fi

if [[ $(id -un) == "root" ]]; then
	echo "ERROR: Do not run this script as root" >> /dev/stderr
	echo "or by using sudo! This will make files" >> /dev/stderr
	echo "created root-only readable and will" >> /dev/stderr
	echo "probably break the installation!" >> /dev/stderr
	echo "Run this as a sudo user instead." >> /dev/stderr
	exit 1
else 
	if [[ $(sudo -v) != "" ]]; then
		echo "ERROR: You must be an administrator user to run" >> /dev/stderr
		echo "this installation script." >> /dev/stderr
		exit 2
	fi
fi
if [[ $(cut -d: -f1 /etc/passwd | grep "_www") != "" ]]; then
	echo "Looks like you already have a user" >> /dev/stderr
	echo "named '_www' which is the default system" >> /dev/stderr
	echo "user for this installation. Either cancel the" >> /dev/stderr
	echo "program (CTRL-C) and remove it OR change the" >> /dev/stderr
	echo "username used here." >> /dev/stderr
	echo "For the latter, re run using..." >> /dev/stderr
	echo "" >> /dev/stderr
	echo "curl https://raw.githubusercontent.com/WJP2003/eclipse-www-server/master/install.bash | bash -s [username_here]" >> /dev/stderr
	exit 3
fi

export wwwuser
sudo -sE -u root <<'EOF'
	printf "Running 'apt-get update'..."
	apt-get -yqq update
	echo "done"

	printf "Running 'apt-get upgrade'..."
	apt-get -yqq upgrade
	echo "done"

	printf "Removing stock Lua 5.2..."
	apt-get -yqq purge lua
	echo "done"

	printf "Installing Lua 5.3..."
	apt-get -yqq install lua5.3
	echo "done"

	printf "Relinking 'lua' command to Lua 5.3..."
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
	luarocks install luasocket | grep -o -m 1 "abc" | grep -o -m 1 "123"
	# | grep -o -m 1 "abc" | grep -o -m 1 "123" hides the output
	echo "done"

	printf "Installing OpenSSL (for useradd password encryption)..."
	apt-get -yqq install openssl
	echo "done"

	printf "Creating new user for web server..."
	useradd -m -p $(echo "alpine" | openssl passwd -1 -stdin) "$wwwuser"
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

	printf "Changing ownership of git repo to www user..."
	chown -R "$wwwuser:nogroup" "/home/eclipse-www-server"
	echo "done"
	
	printf "Changing ownership of www server directory to www user..."
	chown -R "$wwwuser:nogroup" "/home/$wwwuser"
	echo "done"

	printf "Switching to www user..."
EOF

export wwwuser
sudo -sE -u $wwwuser <<'EOF'
	echo "done"

	printf "Cleaning up git repo..."
	rm -rf "/home/eclipse-www-server"
	echo "done"

	printf "Making the web server script executable by only the www user..."
	chmod 744 "/home/$wwwuser/eclipse-www-server.lua"
	echo "done"

	printf "Making the web server root directory locked down..."
	chmod -R 700 "/home/$wwwuser/"

	printf "Switching back to root user..."
EOF

export wwwuser
sudo -sE -u root <<'EOF'
	echo "done"

	printf "Creating terminal command 'eclipse-www-server'..."
	ln -s "/home/$wwwuser/eclipse-www-server.lua" "/usr/local/bin/eclipse-www-server.lua"
	mv "/home/$wwwuser/eclipse-www-server" "/usr/local/bin/eclipse-www-server"
	mv "/home/$wwwuser/eclipse-www-server.kill" "/usr/local/bin/eclipse-www-server.kill"
	chmod 774 "/usr/local/bin/eclipse-www-server"
	chmod 774 "/usr/local/bin/eclipse-www-server.kill"
	echo "done"

	printf "Creating systemd service 'eclipse-www-server'..."
	mv "/home/$wwwuser/eclipse-www-server.service" "/lib/systemd/system/eclipse-www-server.service"
	echo "done"
EOF
echo "Installation complete!"
if [[ "$wwwuser" != "_www" ]]; then
	echo "NOTE: Since there was a _www already,"
	echo "you must change the 2nd line in"
	echo "/home/$wwwuser/eclipse-www-server.lua"
	echo "from $(cat '/home/$wwwuser/eclipse-www-server.lua' | grep 'server_root' -m 1)"
	echo "to $(cat '/home/$wwwuser/eclipse-www-server.lua' | grep 'server_root' -m -1 | xargs sed -i 's/_www/$wwwuser/g')."
fi
read -s -r -p "Press any key to continue..." -n 1
exit 0
