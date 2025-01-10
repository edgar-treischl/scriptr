#!/bin/bash

#ssh root@ip


# Update system
apt-get update || { echo 'ERROR: apt-get update failed' >&2; exit 1; }
apt-get upgrade -y || { echo 'ERROR: apt-get upgrade failed' >&2; exit 1; }

# Install dependencies
apt-get install -y \
gdebi-core \                          # Package installer
libssl-dev \                          # SSL/TLS libraries
libcurl4-openssl-dev \                # cURL
libxml2-dev \                         # XML parsing
default-jdk \                         # Java Development Kit
fail2ban \                            # Security tool to ban IPs after failed login
nginx \                               # Web server
libsodium-dev \                       # Cryptography library for secure operations
libfribidi-dev \                      # Bidirectional text support (useful for languages like Arabic, Hebrew)
libgit2-dev \                         # Git library (for interacting with Git repositories in C/C++ projects)
libharfbuzz-dev \                     # Text shaping and rendering library
libtiff-dev \                         # TIFF image file handling
libpq-dev \                           # PostgreSQL library (for database integration)
libopenblas-dev \                     # High-performance math library (for scientific computing)
pandoc \                              # Document converter
texlive \                             # TeX/LaTeX distribution for document generation
texlive-latex-base \                  # LaTeX base packages
texlive-latex-extra \                 # Additional LaTeX packages
texlive-fonts-recommended \           # Recommended fonts for LaTeX
texlive-fonts-extra \                 # Extra fonts for LaTeX
texlive-lang-german \                 # German language support for LaTeX
texlive-xetex \                       # LaTeX support for modern fonts (e.g., TrueType)
libfreetype-dev \                     # Font rendering library
libfontconfig1-dev \                  # Font configuration library
ufw \                                 # Uncomplicated firewall
libv8-dev                             # V8 JavaScript engine

# Posit's recommended packages:       #(https://docs.posit.co/connect/admin/r/dependencies/index.html)
# libcairo2-dev \                       # Graphics library for rendering (important for R plots)
# make \                                # Tool for building and compiling software (useful for building R packages)
# libmysqlclient-dev \                  # MySQL development libraries (for working with MySQL databases)
# unixodbc-dev \                        # ODBC libraries (for database connectivity)
# libnode-dev \                         # Node.js development libraries (may be required for web or JavaScript integration)
# libx11-dev \                          # X11 libraries (used for GUI development on X-based systems)
# git \                                 # Git version control system
# zlib1g-dev \                          # Compression library (important for many software builds)
# libglpk-dev \                         # Linear programming optimization library
# libjpeg-dev \                         # JPEG image library
# libmagick++-dev \                     # ImageMagick development libraries (useful for image manipulation)
# gsfonts \                             # Fonts for Ghostscript (used for PDF generation)
# cmake \                               # Build system generator (used to compile complex software)
# libpng-dev \                          # PNG image library
# python3 \                             # Python 3 (required for some R packages that interface with Python)
# libglu1-mesa-dev \                    # OpenGL development libraries (for 3D graphics)
# libgl1-mesa-dev \                     # OpenGL libraries (for rendering graphics)
# libgdal-dev \                         # Geospatial Data Abstraction Library (for working with spatial data)
# gdal-bin \                            # GDAL utilities (used for geospatial data processing)
# libgeos-dev \                         # Geometry Engine library (for spatial data operations)
# libproj-dev \                         # Projection library (used with geospatial data)
# libsqlite3-dev \                      # SQLite database libraries
# libicu-dev \                          # International Components for Unicode (for string handling in different languages)
# tcl \                                 # Tcl scripting language (used with Tk for GUI)
# tk \                                  # Tk GUI toolkit (used with Tcl)
# tk-dev \                              # Development files for Tk (needed for building Tk applications)
# tk-table \                            # Tk table widget (used for interactive tables in GUIs)
# libudunits2-dev \                     # Unit conversion library (used for handling units of measurement in R)


# Add R repository
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu 22.04-cran40/"
apt-get update
apt-get install -y r-base r-base-dev

# Add R repository
RSTUDIO_VERSION="2024.09.1-394"
wget -q https://download2.rstudio.org/server/jammy/amd64/rstudio-server-${RSTUDIO_VERSION}-amd64.deb
sudo gdebi -n rstudio-server-${RSTUDIO_VERSION}-amd64.deb
rm rstudio-server-${RSTUDIO_VERSION}-amd64.deb



# Install Pak, Shiny
R -e "install.packages('pak', repos='https://cran.rstudio.com/')"
R -e "pak::pkg_install('shiny')"

# Shiny Server
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.22.1017-amd64.deb
gdebi -n shiny-server-*-amd64.deb
rm shiny-server-*.deb

# Setup directories and permissions
mkdir -p /srv/shiny-server
chown -R shiny:shiny /srv/shiny-server
chmod -R 755 /srv/shiny-server

# Configure logging directories and permissions
mkdir -p /var/log/rstudio
mkdir -p /var/log/shiny-server
touch /var/log/rstudio/rserver-http-access.log
touch /var/log/shiny-server/shiny-server.log
chown -R rstudio-server:rstudio-server /var/log/rstudio
chown -R shiny:shiny /var/log/shiny-server



# Configure Shiny Server logging
cat > /etc/shiny-server/shiny-server.conf <<EOL
# Define the user we should use when spawning R Shiny processes
run_as shiny;

# Define a top-level server which will listen on a port
server {
  listen 3838;

  # Define the location available at the base URL
  location / {
    site_dir /srv/shiny-server;
    log_dir /var/log/shiny-server;
    directory_index on;
  }
}

# Configure logging
preserve_logs true;
access_log /var/log/shiny-server/access.log;  # Logging access requests
log_dir /var/log/shiny-server;
EOL




# Configure logrotate for Shiny Server
cat > /etc/logrotate.d/shiny-server <<EOL
/var/log/shiny-server/*.log {
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        systemctl reload shiny-server > /dev/null 2>/dev/null || true
    endscript
    create 0644 shiny shiny
}
EOL

# Test Shiny Server configuration
if ! systemctl restart shiny-server; then
    echo 'ERROR: Shiny Server failed to restart with new configuration' >&2
    exit 1
fi


if [ ! -f /var/log/shiny-server/access.log ]; then
    echo 'WARNING: Shiny Server access log file not created' >&2
fi

# Configure Fail2ban for RStudio and Shiny Server
cat > /etc/fail2ban/jail.local <<EOL
[rstudio-server]
enabled = true
port = 8787
filter = rstudio-server
logpath = /var/log/rstudio/rserver-http-access.log
maxretry = 3
bantime = 3600

[shiny-server]
enabled = true
port = 3838
filter = shiny-server
logpath = /var/log/shiny-server.log
maxretry = 3
bantime = 3600
EOL

cat > /etc/fail2ban/filter.d/rstudio-server.conf <<EOL
[Definition]
failregex = ^.*Failed login attempt for user .* from IP <HOST>.*$
ignoreregex =
EOL

cat > /etc/fail2ban/filter.d/shiny-server.conf <<EOL
[Definition]
# Detect failed authentication attempts
failregex = ^.*Error in auth.: .* \[ip: <HOST>\].*$
            ^.*Unauthenticated request: .* \[ip: <HOST>\].*$
            ^.*Invalid authentication request from <HOST>.*$
            ^.*Authentication error for .* from <HOST>.*$
            ^.*Failed authentication attempt from <HOST>.*$
ignoreregex =
EOL

systemctl restart fail2ban

# Install and configure UFW firewall
ufw allow ssh
ufw allow http
ufw allow https
ufw allow 8787/tcp
ufw allow 3838/tcp
echo 'y' | ufw enable
if ! ufw status | grep -q 'Status: active'; then
    echo 'ERROR: UFW is not active after enabling' >&2
    exit 1
fi

echo 'UFW is active and configured with the following rules:'
ufw status verbose | tee -a /var/log/ufw-configuration.log

# Configure NGINX as reverse proxy
cat > /etc/nginx/sites-available/r-proxy <<EOL
server {
    listen 80;
    server_name _;

    # RStudio Server
    location /rstudio/ {
        rewrite ^/rstudio/(.*) /\$1 break;
        proxy_pass http://localhost:8787;
        proxy_redirect http://localhost:8787/ \$scheme://\$http_host/rstudio/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 20d;
        proxy_buffering off;
    }

    # Shiny Server
    location /shiny/ {
        rewrite ^/shiny/(.*) /\$1 break;
        proxy_pass http://localhost:3838;
        proxy_redirect http://localhost:3838/ \$scheme://\$http_host/shiny/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 20d;
        proxy_buffering off;
    }
}
EOL

# Add websocket support
cat > /etc/nginx/conf.d/websocket-upgrade.conf <<EOL
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}
EOL

# Enable the site and remove default
ln -s /etc/nginx/sites-available/r-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test NGINX configuration
if ! nginx -t; then
    echo 'ERROR: NGINX configuration test failed' >&2
    exit 1
fi
systemctl restart nginx

# Verify NGINX is running
if ! systemctl is-active --quiet nginx; then
    echo 'ERROR: NGINX failed to restart' >&2
    exit 1
fi

# Verify critical services are running
#Or manual: sudo systemctl status nginx
for service in nginx rstudio-server shiny-server fail2ban; do
    if ! systemctl is-active --quiet $service; then
        echo "ERROR: $service is not running" >&2
        exit 1
    fi



# Install R packages: This may take some time: 110 R packages
sudo R --vanilla << EOF || { echo 'ERROR: R package installation failed' >&2; exit 1; }
pak::pkg_install(c('renv', 'DBI', 'RPostgreSQL', 'dbplyr', 'dplyr', 'tidyr', 'readr', 'purrr', 'stringr', 'forcats', 'lubridate', 'jsonlite', 'devtools', 'roxygen2', 'testthat', 'rmarkdown', 'pkgdown', 'tinytex', 'ggplot2', 'showtext', 'ggtext', 'plotly', 'shiny', 'htmltools', 'bslib', 'xml2', 'parallel', 'future', 'furrr'))
q()
EOF






# Add single user
# sudo adduser edgar
# sudo usermod -aG rstudio-server edgar

# We need an account for each team member
# Common start password for all users
START_PASSWORD="Temp@1234"

# List of users to create
users=("edgar" "stefan" "victoria")

# Create users and set the start password
for user in "${users[@]}"; do
    # Create user without setting a password initially
    sudo adduser --disabled-password --gecos "" "$user"

    # Set the start password for the user using chpasswd
    echo "$user:$START_PASSWORD" | sudo chpasswd

    # Add user to the rstudio-server group
    sudo usermod -aG rstudio-server "$user"

    echo "User $user created and added to rstudio-server group with start password."
done


# Go to:
# R Studio Server
#http://<your-vm-ip>:8787

# Shiny Server
#http://<your-vm-ip>:3838



#Debugging
# List of packages to check
# packages=("gdebi-core" "libssl-dev" "libcurl4-openssl-dev" "libxml2-dev" "default-jdk" "fail2ban" "nginx" "libsodium-dev" "libpq-dev" "libopenblas-dev" "pandoc" "texlive-full" "libfreetype-dev" "libfontconfig1-dev")
#
# # Loop over the package list and check if each is installed
# for pkg in "${packages[@]}"; do
#     if ! dpkg-query -l "$pkg" &>/dev/null; then
#         echo "$pkg is NOT installed."
#     else
#         echo "$pkg is installed."
#     fi
# done
