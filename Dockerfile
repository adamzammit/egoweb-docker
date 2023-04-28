FROM php:8.0-apache

ENV DOWNLOAD_URL https://github.com/qualintitative/egoweb/archive/215700eade32e387d3a50db89275fb8dd1249478.zip

# install the PHP extensions we need
RUN apt-get update && apt-get install -y unzip libmcrypt-dev libpng-dev libjpeg-dev mariadb-client libfreetype6-dev libicu-dev && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd --with-jpeg=/usr -with-freetype=/usr/include/ \
    && pecl install mcrypt-1.0.6 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install gd mysqli opcache pdo pdo_mysql iconv intl

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN a2enmod rewrite expires

RUN set -x; \
    curl -SL "$DOWNLOAD_URL" -o /tmp/egoweb.zip; \
    unzip /tmp/egoweb.zip -d /tmp; \
    rm /tmp/egoweb.zip; \
    mv /tmp/egoweb* /tmp/egoweb; \
    mv /tmp/egoweb/app/* /var/www/html/; \
    mv /tmp/egoweb/app/.[a-zA-Z]* /var/www/html/; \
    chown -R www-data:www-data /var/www/html

RUN { \
        echo 'memory_limit=256M'; \
        echo 'upload_max_filesize=128M'; \
        echo 'post_max_size=128M'; \
        echo 'max_execution_time=120'; \
        echo 'max_input_vars=10000'; \
        echo 'date.timezone=UTC'; \
        echo 'expose_php=Off'; \
    } > /usr/local/etc/php/conf.d/uploads.ini

VOLUME ["/var/www/html/protected/config"]

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

# ENTRYPOINT resets CMD
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
