# Set the base image to Ubuntu 22.04 (Jammy Jellyfish)
FROM ubuntu:jammy

# Change from /bin/sh to /bin/bash
SHELL ["/bin/bash", "-c"]

# Set maintainer label in lowercase
LABEL maintainer="Dan Dinu <dan.dinu.ro@gmail.com>"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PHP_VERSION=8.1 \
    SCRIPTCASE_VERSION=9.9.020 \
#    WORKING_DIR=/var/www/html/ \
    HTTP_PORT=80
# Environment settings
ARG DEBIAN_FRONTEND=noninteractive
ENV HTTP_PORT=80
ENV HTTPS_PORT=443
ENV PHP_VERSION=8.1
ENV SCRIPTCASE_VERSION=9.9.020

# make software preparation with update and install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    nano \
    unzip \
    mc

# install apache
RUN apt-get install -y apache2

# install PHP + necesaire modules
RUN apt-get install -y \
    php${PHP_VERSION} \
    libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-cgi \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-xsl \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-sqlite3

# system refresh
RUN service apache2 restart

# Download and install ixed.8.1.lin
RUN mkdir workplace && \
    cd /workplace && \
    curl -O https://www.sourceguardian.com/loaders/download/loaders.linux-x86_64.zip && \
    chmod 777 loaders.linux-x86_64.zip && unzip loaders.linux-x86_64.zip && \
    cp ixed.8.1.lin /usr/lib/php/20210902/ && \
    rm -rf /workplace

# Update php.ini with custom values requested by scriptcase
RUN sed -i 's/;date.timezone =/date.timezone = ${TZ}/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/max_execution_time = 30/max_execution_time = 3600/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/max_input_time = 60/max_input_time = 3600/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/max_input_vars = 1000/max_input_vars = 10000/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/memory_limit = 128M/memory_limit = 1024M/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/post_max_size = 8M/post_max_size = 1024M/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 1024M/' /etc/php/${PHP_VERSION}/apache2/php.ini && \
    sed -i 's/max_file_uploads = 20/max_file_uploads = 200/' /etc/php/${PHP_VERSION}/apache2/php.ini

# add zend extantion
RUN echo "zend_extension = \"/usr/lib/php/20210902/ixed.8.1.lin\"" >> /etc/php/${PHP_VERSION}/apache2/php.ini

# Insert ServerName in httpd.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# system refresh
RUN service apache2 restart

# Create a non-root user for running Laravel
RUN useradd -m -s /bin/bash skipper

# add writing rights over directory /config and /var/www/html for skipper user
RUN chown -R skipper:skipper /var/www/html

# Add the `www-data` user to the `skipper` group
RUN usermod -a -G skipper www-data

# Set the ownership of /var/www/html to the `www-data` group
RUN chown -R :www-data /var/www/html

# Set the permissions to allow the `www-data` group to write
RUN chmod -R 775 /var/www/html

# Install Laravel globally for the non-root user
USER skipper

# Download and install Scriptcase
RUN cd /var/www/html && \
    curl -O https://downloads.scriptcase.net/v9/packs/scriptcase-${SCRIPTCASE_VERSION}-en_us-php${PHP_VERSION}.zip && \
    unzip scriptcase-${SCRIPTCASE_VERSION}-en_us-php${PHP_VERSION}.zip && \
    mv scriptcase-${SCRIPTCASE_VERSION}-en_us-php${PHP_VERSION} netmake && \
    rm /var/www/html/index.html && \
    echo '<html><head><meta http-equiv="refresh" content="0;url=/netmake"></head></html>' > /var/www/html/index.html && \
    rm scriptcase-${SCRIPTCASE_VERSION}-en_us-php${PHP_VERSION}.zip

# create info.php
RUN echo "<?php phpinfo(); ?>" >> /var/www/html/info.php

# Switch back to the root user to configure supervisord
USER root

# Clean the ebviroment after installing
RUN apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

#Run apache2 in forground
CMD ["apache2ctl", "-D", "FOREGROUND"]
