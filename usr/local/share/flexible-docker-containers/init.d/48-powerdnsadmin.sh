#!/bin/bash
# Copyright (c) 2022-2023, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


fdc_notice "Setting up PowerDNS Admin"

if [ ! -e /etc/powerdnsadmin ]; then
	mkdir /etc/powerdnsadmin
fi
chown root:gunicorn /etc/powerdnsadmin
chmod 0750 /etc/powerdnsadmin

if [ ! -e /etc/powerdnsadmin/config.env ]; then
	touch /etc/powerdnsadmin/config.env
fi
chown root:gunicorn /etc/powerdnsadmin/config.env
chmod 0640 /etc/powerdnsadmin/config.env

if [ ! -e /run/gunicorn/flask_session ]; then
	mkdir /run/gunicorn/flask_session
fi
chown root:gunicorn /run/gunicorn/flask_session
chmod 0770 /run/gunicorn/flask_session


# Adjust Gunicorn configuration for PowerDNS Admin
sed \
	-e 's/GUNICORN_MODULE=app/GUNICORN_MODULE=powerdnsadmin/' \
	-e 's/GUNICORN_CALLABLE=app/GUNICORN_CALLABLE="create_app()"/' \
	-i /etc/gunicorn/gunicorn.conf

# Work out which database is configured
db_configured=
if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ] && [ -n "$MYSQL_DATABASE" ]; then
	db_configured=mysql
elif [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_PASSWORD" ] && [ -n "$POSTGRES_DATABASE" ]; then
	db_configured=postgres
elif [ -n "$PDNSA_SQLALCHEMY_DATABASE_URI" ]; then
	db_configured=manual
fi
if [ -z "$db_configured" ]; then
	fdc_error "PowerDNS Admin needs database configuration"
	false
fi

if [ -z "$PDNSA_CAPTCHA_SESSION_KEY" ]; then
	fdc_error "PowerDNS Admin environment variable 'PDNSA_CAPTCHA_SESSION_KEY' is mandatory"
	false
fi

if [ -z "$PDNSA_SALT" ]; then
	fdc_error "PowerDNS Admin environment variable 'PDNSA_SALT' is mandatory"
	false
fi

if [ -z "$PDNSA_SECRET_KEY" ]; then
	fdc_error "PowerDNS Admin environment variable 'PDNSA_SECRET_KEY' is mandatory"
	false
fi


# Set defaults
PDNSA_SESSION_COOKIE_SAMESITE="${PDNSA_SESSION_COOKIE_SAMESITE:-Lax}"
PDNSA_CSRF_COOKIE_HTTPONLY="${PDNSA_CSRF_COOKIE_HTTPONLY:-True}"

PDNSA_SESSION_TYPE="${PDNSA_SESSION_TYPE:-sqlalchemy}"

PDNSA_SAML_ENABLED="${PDNSA_SAML_ENABLED:-False}"
PDNSA_SAML_ASSERTION_ENCRYPTED="${PDNSA_SAML_ASSERTION_ENCRYPTED:-True}"

PDNSA_HSTS_ENABLED="${PDNSA_HSTS_ENABLED:-False}"

PDNSA_CAPTCHA_ENABLE="${PDNSA_CAPTCHA_ENABLE:-True}"
PDNSA_CAPTCHA_LENGTH="${PDNSA_CAPTCHA_LENGTH:-6}"
PDNSA_CAPTCHA_WIDTH="${PDNSA_CAPTCHA_WIDTH:-160}"
PDNSA_CAPTCHA_HEIGHT="${PDNSA_CAPTCHA_HEIGHT:-60}"

PDNSA_SQLALCHEMY_TRACK_MODIFICATIONS="${PDNSA_SQLALCHEMY_TRACK_MODIFICATIONS:-True}"

PDNSA_LOG_FILE="${PDNSA_LOG_FILE:-}"


# Setup database URI depending on the configured database type
if [ "$db_configured" = "postgres" ]; then
	export PGPASSWORD="$POSTGRES_PASSWORD"

	# shellcheck disable=SC2034
	PDNSA_SQLALCHEMY_DATABASE_URI="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST/$POSTGRES_DATABASE"

	while true; do
		fdc_notice "PowerDNS waiting for PostgreSQL server '$POSTGRES_HOST'..."
		if pg_isready -d "$POSTGRES_DATABASE" -h "$POSTGRES_HOST" -U "$POSTGRES_USER"; then
			break
		fi
		sleep 1
	done

	unset PGPASSWORD

elif [ "$db_configured" = "mysql" ]; then
	export MYSQL_PWD="$MYSQL_PASSWORD"

	# shellcheck disable=SC2034
	PDNSA_SQLALCHEMY_DATABASE_URI="mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST/$MYSQL_DATABASE"

	while true; do
		fdc_notice "PowerDNS Admin waiting for MySQL server '$MYSQL_HOST'..."

		if mysqladmin ping --host "$MYSQL_HOST" --user "$MYSQL_USER" --silent --connect-timeout=2; then
			break
		fi
		sleep 1
	done

	unset MYSQL_PWD
fi


# Check if we were given an initial username and password
if [ -n "$PDNSA_ADMIN_USERNAME" ] && [ -n "$PDNSA_ADMIN_PASSWORD" ]; then
	INITIAL_ADMIN_USERNAME="${PDNSA_ADMIN_USERNAME}"
	INITIAL_ADMIN_PASSWORD_ENC=$(echo "$PDNSA_ADMIN_PASSWORD" | powerdnsadmin-hashpw)
fi
unset PDNSA_ADMIN_USERNAME
unset PDNSA_ADMIN_PASSWORD


# Write out PowerDNS Admin config variables
set | grep -E '^PDNSA_[^=]+=' | sed -e 's/^PDNSA_//' > /etc/powerdnsadmin/config.env


# Do database upgrade on each start
(
	set -a
	# shellcheck disable=1091
	. /etc/powerdnsadmin/config.env
	set +a

	fdc_info "Running PowerDNS Admin database upgrade..."
	su -s /bin/sh gunicorn -c /usr/local/sbin/powerdnsadmin-upgrade
)


# Setup database URI depending on the configured database type
if [ "$db_configured" = "postgres" ]; then
	export PGPASSWORD="$POSTGRES_PASSWORD"

	# Check if the domain table exists, if not, create the database
	results=$(echo "SELECT * FROM setting WHERE name = 'bg_domain_updates';" | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -w "$POSTGRES_DATABASE" -v ON_ERROR_STOP=ON 2>&1)
	if ! echo "$results" | grep -q "bg_domain_updates"; then
		fdc_info "Setting up PostgreSQL defaults for PowerDNS Admin"
		cat <<EOF | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -w "$POSTGRES_DATABASE" -v ON_ERROR_STOP=ON
INSERT INTO setting (name, value) VALUES ('bg_domain_updates', True);
EOF

	fi

	# Setup or update up the PDNS server
	if [ -n "$POWERDNS_API_URL" ] && [ -n "$POWERDNS_API_KEY" ]; then
		# Set default version if not specified
		POWERDNS_VERSION="${POWERDNS_VERSION:-4.1.1}"

		fdc_info "Setting up PowerDNS Backend API settings in PostgreSQL"
		cat <<EOF | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -w "$POSTGRES_DATABASE" -v ON_ERROR_STOP=ON
INSERT INTO setting (name, value) VALUES ('pdns_api_url', '$POWERDNS_API_URL')
	ON CONFLICT (name) DO UPDATE SET value = '$POWERDNS_API_URL';
INSERT INTO setting (name, value) VALUES ('pdns_api_key', '$POWERDNS_API_KEY')
	ON CONFLICT (name) DO UPDATE SET value = '$POWERDNS_API_KEY';
INSERT INTO setting (name, value) VALUES ('pdns_version', '$POWERDNS_VERSION')
	ON CONFLICT (name) DO UPDATE SET value = '$POWERDNS_API_VERSION';
EOF
	fi

	# Check if we're creating an initial admin username/password
	if [ -n "$INITIAL_ADMIN_USERNAME" ] && [ -n "$INITIAL_ADMIN_PASSWORD_ENC" ]; then
		results=$(echo "SELECT COUNT(*) FROM \"user\" WHERE id = 1 OR username = '$INITIAL_ADMIN_USERNAME';" | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -w "$POSTGRES_DATABASE" -v ON_ERROR_STOP=ON -At 2>&1)
		if [ "$results" = "0" ]; then
			fdc_info "Setting up PostgreSQL initial admin user for PowerDNS Admin"
			cat <<EOF | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -w "$POSTGRES_DATABASE" -v ON_ERROR_STOP=ON
INSERT INTO "user" (username, password, role_id, confirmed) VALUES ('$INITIAL_ADMIN_USERNAME', '$INITIAL_ADMIN_PASSWORD_ENC', 1, false);
EOF
		fi
	fi

	unset PGPASSWORD


elif [ "$db_configured" = "mysql" ]; then
	export MYSQL_PWD="$MYSQL_PASSWORD"

	# Check if the domain table exists, if not, create the database
	results=$(echo "SELECT * FROM setting WHERE name = 'bg_domain_updates';" | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -s "$MYSQL_DATABASE" 2>&1)
	if ! echo "$results" | grep -q "bg_domain_updates"; then
		fdc_info "Setting up MySQL defaults for PowerDNS Admin"
		cat <<EOF | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE"
INSERT INTO setting (name, value) VALUES ("bg_domain_updates", true);
EOF
	fi

	# Setup or update up the PDNS server
	if [ -n "$POWERDNS_API_URL" ] && [ -n "$POWERDNS_API_KEY" ]; then
		# Set default version if not specified
		POWERDNS_VERSION="${POWERDNS_VERSION:-4.1.1}"

		fdc_info "Setting up PowerDNS Backend API settings in MySQL"
		cat <<EOF | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE"
INSERT INTO setting (name, value) VALUES ("pdns_api_url", "$POWERDNS_API_URL")
	ON DUPLICATE KEY UPDATE value = "$POWERDNS_API_URL";
INSERT INTO setting (name, value) VALUES ("pdns_api_key", "$POWERDNS_API_KEY")
	ON DUPLICATE KEY UPDATE value = "$POWERDNS_API_KEY";
INSERT INTO setting (name, value) VALUES ("pdns_version", "$POWERDNS_VERSION")
	ON DUPLICATE KEY UPDATE value = "$POWERDNS_VERSION";
EOF
	fi

	# Check if we're creating an initial admin username/password
	if [ -n "$INITIAL_ADMIN_USERNAME" ] && [ -n "$INITIAL_ADMIN_PASSWORD_ENC" ]; then
		results=$(echo "SELECT COUNT(*) FROM user WHERE id = 1 OR username = '$INITIAL_ADMIN_USERNAME';" | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -s "$MYSQL_DATABASE" 2>&1)
		if [ "$results" = "0" ]; then
			fdc_info "Setting up MySQL initial admin user for PowerDNS Admin"
			cat <<EOF | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE"
INSERT INTO user (username, password, firstname, lastname, email, role_id, confirmed) VALUES ("$INITIAL_ADMIN_USERNAME", "$INITIAL_ADMIN_PASSWORD_ENC", "Admin", "Admin", "admin@example.com", 1, false);
EOF
		fi
	fi

	unset MYSQL_PWD
fi

