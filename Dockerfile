FROM php:8.2-apache

WORKDIR /var/www/html

COPY php/public/ /var/www/html/
COPY php/src/ /var/www/html/src/

RUN mkdir -p /var/www/html/uploads_glb \
    && chown -R www-data:www-data /var/www/html

COPY docker/php-upload.ini /usr/local/etc/php/conf.d/php-upload.ini

EXPOSE 80
