#!/bin/bash
set -eu

cd /var/www/html

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
	file_env 'EGOWEB_DB_HOST' 'mysql'

	# if we're linked to MySQL and thus have credentials already, let's use them
	file_env 'EGOWEB_DB_USER' "${MYSQL_ENV_MYSQL_USER:-root}"
	if [ "$EGOWEB_DB_USER" = 'root' ]; then
		file_env 'EGOWEB_DB_PASSWORD' "${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}"
	else
		file_env 'EGOWEB_DB_PASSWORD' "${MYSQL_ENV_MYSQL_PASSWORD:-}"
	fi
	file_env 'EGOWEB_DB_NAME' "${MYSQL_ENV_MYSQL_DATABASE:-egoweb}"
	if [ -z "$EGOWEB_DB_PASSWORD" ]; then
		echo >&2 'error: missing required EGOWEB_DB_PASSWORD environment variable'
		echo >&2 '  Did you forget to -e EGOWEB_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 '  (Also of interest might be EGOWEB_DB_USER and EGOWEB_DB_NAME.)'
		exit 1
	fi

    #Run initialize script on each startup
    ./initialize.sh

    # see http://stackoverflow.com/a/2705678/433558
    sed_escape_lhs() {
        echo "$@" | sed -e 's/[]\/$*.^|[]/\\&/g'
    }
    sed_escape_rhs() {
        echo "$@" | sed -e 's/[\/&]/\\&/g'
    }
    php_escape() {
        php -r 'var_export(('$2') $argv[1]);' -- "$1"
    }
    set_config() {
        key="$1"
        value="$2"
        sed -i "/'$key'/s/>\(.*\)/>$value,/1"  protected/config/main.php
    }

    set_config 'dsn' "'mysql:host=$EGOWEB_DB_HOST;dbname=$EGOWEB_DB_NAME'"
    set_config 'username' "'$EGOWEB_DB_USER'"
    set_config 'password' "'$EGOWEB_DB_PASSWORD'"

	DBSTATUS=$(TERM=dumb php -- "$EGOWEB_DB_HOST" "$EGOWEB_DB_USER" "$EGOWEB_DB_PASSWORD" "$EGOWEB_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

error_reporting(E_ERROR | E_PARSE);

$stderr = fopen('php://stderr', 'w');

list($host, $socket) = explode(':', $argv[1], 2);
$port = 0;
if (is_numeric($socket)) {
        $port = (int) $socket;
        $socket = null;
}

$maxTries = 50;
do {
    $con = mysqli_init();
    $mysql = mysqli_real_connect($con,$host, $argv[2], $argv[3], '', $port, $socket, MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT);
        if (!$mysql) {
                fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
                --$maxTries;
                if ($maxTries <= 0) {
                        exit(1);
                }
                sleep(3);
        }
} while (!$mysql);

if (!$con->query('CREATE DATABASE IF NOT EXISTS `' . $con->real_escape_string($argv[4]) . '`')) {
        fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $con->error . "\n");
        $con->close();
        exit(1);
}

$con->select_db($con->real_escape_string($argv[4]));

if (!$con->query('SELECT * FROM `tbl_migration`')) {
    fwrite($stderr, "\n" . 'Cannot find Egoweb database. Will now populate... ' . $con->error . "\n");

    $command = 'mysql'
        . ' --host=' . $host
        . ' --user=' . $argv[2]
        . ' --password=' . $argv[3]
        . ' --database=' . $argv[4]
        . ' --execute="SOURCE ';

    fwrite($stderr, "\n" . 'Loading Egoweb database...' . "\n");
    $output1 = shell_exec($command . '/tmp/egoweb/sql/egoweb_db.sql"');
    fwrite($stderr, "\n" . 'Loaded Egoweb database: ' . $output1 . "\n");
    } else {
      fwrite($stderr, "\n" . 'Egoweb Database found. Leaving unchanged.' . "\n");
    }


$con->close();


EOPHP
)


fi

exec "$@"
