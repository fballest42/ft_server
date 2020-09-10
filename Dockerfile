# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: fballest <fballest@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/08/13 10:35:01 by fballest          #+#    #+#              #
#    Updated: 2020/09/10 12:49:32 by fballest         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# 0.- OS DEFINITION
FROM debian:buster

# 00.- AUTHOR
LABEL mantainer="Fernando Ballesteros  <fballest@student.42madrid.es>"

# 1.- DEFINITION OF ARGUMENTS & ENVIROMENT VARIABLES TO BUILD THE IMAGES

# 1.1.- Mysql Root Password
ARG MYSQL_ROOT_PASSWORD=mysql_password

# 1.2.- Wordpress database
ARG WORDPRESS_DATABASE=wordpress
ARG WORDPRESS_DATABASE_USER=wordpress_database_admin
ARG WORDPRESS_DATABASE_PASS=wordpress_database_pass

# 1.3.- Wordpress configuration
ARG WORDPRESS_URL=localhost
ARG WORDPRESS_SITE_TITLE=ft_server
ARG WORDPRESS_ADMIN_NAME=wordpress_admin
ARG WORDPRESS_ADMIN_EMAIL=ballesteros.fdo@gmail.com
ARG WORDPRESS_ADMIN_PASSWORD=wordpress_password

# 1.4.- PhpMyAdmin version
ARG PHPMYADMIN_VERSION=5.0.2

# 1.5.- PhpMyAdmin PMA password
ARG PMA_USER_DATABASE_PASSWORD=pma_user_database_password

# 1.6.- User for mysql database
ARG DATABASE_USER=database_admin
ARG DATABASE_USER_PASSWORD=database_password

# 2.- AUTOINDEX: GIVE IT ANY POSITIVE VALUE FOR AUTOINDEX ON OR KEEP IT BLANK FOR AUTOINDEX OFF
ENV NGINX_AUTOINDEX=

# 3.- RUNING NGINX, MARIADB, PHP & SSL,
RUN apt-get -qq update \
 && apt-get -qq upgrade \
 && apt-get -qq install \
    nginx \
    mariadb-server \
    php-fpm \
    php-mysql \
    openssl \
    wget

# 4.- COPY NGINX DEFAULT CONFIG & AUTOINDEX TO IMAGE

COPY srcs/nginx-default /etc/nginx/sites-available/default
COPY srcs/nginx-autoindex /nginx-autoindex

# 5.- PHP & MYSQL & CREATE DB FOR WORDPRESS

RUN sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0;/g' etc/php/7.3/fpm/php.ini \
 && service mysql start \
 && mysql -e "UPDATE mysql.user SET password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';" \
 && mysql -e "DELETE FROM mysql.user WHERE User='';" \
 && mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" \
 && mysql -e "DROP DATABASE IF EXISTS test;" \
 && mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" \
 && mysql -e "CREATE DATABASE ${WORDPRESS_DATABASE} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;" \
 && mysql -e "GRANT ALL ON ${WORDPRESS_DATABASE}.* TO '${WORDPRESS_DATABASE_USER}'@'localhost' IDENTIFIED BY '${WORDPRESS_DATABASE_PASS}';" \
 && sleep 1 \
 && service mysql stop \
 && openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj '/CN=127.0.0.1'

# 6.- RUNING WORDPRESS

RUN wget -q https://wordpress.org/latest.tar.gz -P tmp \
 && tar xzf tmp/latest.tar.gz -C tmp \
 && cp -r tmp/wordpress/* /var/www/html/ \
 && cd /var/www/html \
 && wget -q https://api.wordpress.org/secret-key/1.1/salt/ -O salt \
 && csplit -s wp-config-sample.php '/AUTH_KEY/' '/NONCE_SALT/+1' \
 && cat xx00 salt xx02 > wp-config.php \
 && rm salt xx00 xx01 xx02 \
 && cd / \
 && sed -i -e "s/database_name_here/${WORDPRESS_DATABASE}/" -e "s/username_here/${WORDPRESS_DATABASE_USER}/" -e "s/password_here/${WORDPRESS_DATABASE_PASS}/" var/www/html/wp-config.php \
 && wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /tmp/ \
 && chmod +x tmp/wp-cli.phar \
 && mv tmp/wp-cli.phar usr/local/bin/wp \
 && service mysql start \
 && wp core install --url=${WORDPRESS_URL} --title=${WORDPRESS_SITE_TITLE} --admin_name=${WORDPRESS_ADMIN_NAME} --admin_email=${WORDPRESS_ADMIN_EMAIL} --admin_password=${WORDPRESS_ADMIN_PASSWORD} --allow-root --path='var/www/html/' --skip-email --quiet \
 && wp theme install twentyseventeen --activate --allow-root --path=/var/www/html --quiet \
 && wp plugin uninstall hello --path=var/www/html/ --allow-root --quiet \
 && wp plugin uninstall akismet --path=var/www/html/ --allow-root --quiet \
 && wp theme delete twentysixteen --allow-root --path=/var/www/html --quiet \
 && wp theme delete twentynineteen --allow-root --path=/var/www/html --quiet \
 && wp theme delete twentytwenty --allow-root --path=/var/www/html --quiet \
 && wp search-replace 'Just another WordPress site' 'Cursus Project 42Madrid' --allow-root --path=var/www/html --quiet \
 && wp search-replace 'Aloha world!' '42Madrid' --allow-root --path=var/www/html --quiet \
 && wp search-replace 'A WordPress Commenter' 'fballest' --allow-root --path=var/www/html --quiet \
 && wp search-replace 'Welcome to WordPress. This is your first post. Edit or delete it, then start writing!' 'Wellcome to my ft_server project... ' --allow-root --path=var/www/html --quiet \
 && service mysql stop \
 && chown -R www-data:www-data /var/www/html/

### RUNING PHPMYADMIN

RUN wget -q https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -P tmp \
 && tar xzf tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -C tmp \
 && mv tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages/ /usr/share/phpmyadmin \
 && mkdir -p /var/lib/phpmyadmin/tmp \
 && chown -R www-data:www-data /var/lib/phpmyadmin \
 && randomBlowfishSecret=$(openssl rand -base64 32) \
 && sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" -e '/controluser/,/End/ s/^\/\///g' /usr/share/phpmyadmin/config.sample.inc.php > /usr/share/phpmyadmin/config.inc.php \
 && sed -i "s/pmapass/${PMA_USER_DATABASE_PASSWORD}/" /usr/share/phpmyadmin/config.inc.php \
 && echo "\$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';" >> /usr/share/phpmyadmin/config.inc.php \
 && service mysql start \
 && mariadb < /usr/share/phpmyadmin/sql/create_tables.sql \
 && mysql -e "GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO 'pma'@'localhost' IDENTIFIED BY '${PMA_USER_DATABASE_PASSWORD}';" \
 && mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${DATABASE_USER}'@'localhost' IDENTIFIED BY '${DATABASE_USER_PASSWORD}';" \
 && sleep 1 \
 && service mysql stop \
 && ln -s /usr/share/phpmyadmin /var/www/html/ \
 && rm -rf tmp/* \
 && wget -q https://www.42madrid.com/wp-content/uploads/2020/04/Campus-42-Madrid.jpg -O /var/www/html/wp-content/themes/twentyseventeen/assets/images/header.jpg

### AUTOINDEX DETECTION, STARTING SERVICES AND KEEP IT RUNING

CMD if [ -n "${NGINX_AUTOINDEX}" ] ; then cp /nginx-autoindex /etc/nginx/sites-available/default; fi \
 && service php7.3-fpm start && service mysql start && nginx && tail -f /dev/null

### PORTS EXPOSED DO NOT FORGET TO USE FLAGS AT RUN TIME: -p [host port]:[container port]

EXPOSE 80
EXPOSE 443
