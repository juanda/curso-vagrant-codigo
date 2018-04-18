#! /usr/bin/env bash

###
# Adaptado de:
# https://gist.github.com/rrosiek/8190550
# provision.sh
#
###

# Variables
DBHOST=localhost
DBNAME=blog
DBUSER=bloguser
DBPASSWD=test123

echo -e "\n--- Realizando provisión de software... ---\n"

echo -e "\n--- Actualizando la lista de paquetes ---\n"
apt-get update

echo -e "\n--- Instalando paquetes base ---\n"
apt-get -y install vim curl build-essential python-software-properties git >> /home/vagrant/vm_build.log 2>&1

# Instalación de MySQL (sólo para desarrollo)
echo -e "\n--- Instalando paquetes de MySQL ---\n"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $DBPASSWD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DBPASSWD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none"
apt-get -y install mysql-server phpmyadmin >> /home/vagrant/vm_build.log 2>&1

echo -e "\n--- Configurando  MySQL: usuario y base de datos  ---\n"
mysql -uroot -p$DBPASSWD -e "CREATE DATABASE $DBNAME" >> /home/vagrant/vm_build.log 2>&1
mysql -uroot -p$DBPASSWD -e "grant all privileges on $DBNAME.* to '$DBUSER'@'localhost' identified by '$DBPASSWD'" > /home/vagrant/vm_build.log 2>&1

echo -e "\n--- Instalando paquetes de PHP ---\n"
apt-get -y install php apache2 libapache2-mod-php php-curl php-gd php-mysql php-gettext >> /home/vagrant/vm_build.log 2>&1

echo -e "\n--- Habilitando mod-rewrite ---\n"
a2enmod rewrite >> /home/vagrant/vm_build.log 2>&1

echo -e "\n--- Permitiendo a  Apache override all ---\n"
sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

echo -e "\n--- Definiendo el document root a /var/www/blog/web (como lo requiere symfony) ---\n"
sed -i "s/www\/html/www\/blog\/web/" /etc/apache2/sites-enabled/000-default.conf

echo -e "\n--- Activamos PHP errors ---\n"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/apache2/php.ini

echo -e "\n--- Reiniciando Apache ---\n"
service apache2 restart >> /home/vagrant/vm_build.log 2>&1

echo -e "\n--- Instalando Composer para gestión de paquetes PHP ---\n"
curl --silent https://getcomposer.org/installer | php >> /home/vagrant/vm_build.log 2>&1
mv composer.phar /usr/local/bin/composer

echo -e "\n--- Actualizando componentes del projecto ---\n"

cd /var/www/blog

if [[ -s /var/www/blog/composer.json ]] ;then
  sudo -u vagrant -H sh -c "composer install" >> /home/vagrant/vm_build.log 2>&1
fi

echo -e "\n--- Configurando aplicación blog ---\n"

sed -i "s/database_password: null/database_password: test123/" /var/www/blog/app/config/parameters.yml

echo -e "\n--- Creando enlace simbólico para uso futiro de phpunit ---\n"

if [[ -x /var/www/blog/vendor/bin/phpunit ]] ;then
  ln -fs /var/www/blog/vendor/bin/phpunit /usr/local/bin/phpunit
fi

echo -e "\n--- Creando la base de datos y rellenándola ---\n"

sudo -u vagrant -H sh -c "php /var/www/blog/bin/console doctrine:database:create" >> /home/vagrant/vm_build.log 2>&1
sudo -u vagrant -H sh -c "php /var/www/blog/bin/console doctrine:schema:create" >> /home/vagrant/vm_build.log 2>&1
sudo -u vagrant -H sh -c "php /var/www/blog/bin/console doctrine:fixtures:load" >> /home/vagrant/vm_build.log 2>&1