egoweb-docker
==========

Egoweb - https://github.com/qualintitative/egoweb 

This docker image is for running Egoweb on apache/php in its own container. It accepts environment variables to update the configuration file. On first run it will automatically create the database. Currently this is tracking the "dev" branch and images will be tagged based on the commit hashes from the dev branch.

Volumes are specified for the configuration directory for persistence.

# How to use this image

The following environment variables are also honored for configuring your Egoweb instance. If Egoweb is already installed, these environment variables will update the config file.

-	`-e EGOWEB_DB_HOST=...` (defaults to the IP and port of the linked `mysql` container)
-	`-e EGOWEB_DB_USER=...` (defaults to "root")
-	`-e EGOWEB_DB_PASSWORD=...` (defaults to the value of the `MYSQL_ROOT_PASSWORD` environment variable from the linked `mysql` container)
-	`-e EGOWEB_DB_NAME=...` (defaults to "egoweb")

If the `EGOWEB_DB_NAME` specified does not already exist on the given MySQL server, it will be created automatically upon startup of the `egoweb` container, provided that the `EGOWEB_DB_USER` specified has the necessary permissions to create it.

If you'd like to use an external database instead of a linked `mysql` container, specify the hostname and port with `EGOWEB_DB_HOST` along with the password in `EGOWEB_DB_PASSWORD` and the username in `EGOWEB_DB_USER` (if it is something other than `root`):

## ... via [`docker-compose`](https://github.com/docker/compose)

Example `docker-compose.yml` for `egoweb`:

```yaml
version: '2'

services:

  egoweb:
    image: acspri/egoweb
    ports:
      - 8082:80
    environment:
      EGOWEB_DB_PASSWORD: example

  mysql:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: example
```

Run `docker-compose up`, wait for it to initialize completely, and visit `http://localhost:8082` or `http://host-ip:8082`.

# Supported Docker versions

This image is officially supported on Docker version 1.12.3.

Support for older versions (down to 1.6) is provided on a best-effort basis.

Please see [the Docker installation documentation](https://docs.docker.com/installation/) for details on how to upgrade your Docker daemon.

Notes
-----

This Dockerfile is based on the Dockerfile from the [Wordpress official docker image](https://github.com/docker-library/wordpress/tree/8ab70dd61a996d58c0addf4867a768efe649bf65/php5.6/apache)
