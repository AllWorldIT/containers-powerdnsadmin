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

FROM registry.conarx.tech/containers/nginx-gunicorn/3.17 as builder

ENV POWERDNS_ADMIN_VER=0.4.1
ENV POWERDNS_ADMIN_COMMIT=xxx


#COPY patches /build/patches


RUN set -eux; \
	true "PowerDNS Admin Build Dependencies"; \
	apk add --no-cache \
		coreutils \
		git \
		patch \
		libffi-dev \
		libxml2-dev \
		mariadb-connector-c-dev \
		openldap-dev \
		python3-dev \
		py3-pip \
		py3-psycopg2 \
		xmlsec-dev \
		npm \
		yarn \
		cargo;

RUN set -eux; \
	mkdir -p build; \
	cd build; \
	true "PowerDNS Admin Download"; \
	# NK: Shallow clone on commit id - remove on next version release
	# mkdir "PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	# cd "PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	# git init; \
	# git remote add origin https://github.com/PowerDNS-Admin/PowerDNS-Admin.git; \
	# git fetch --depth 1 origin "$POWERDNS_ADMIN_COMMIT"; \
	# git checkout FETCH_HEAD
	# NK: Replace with wget on version on next release
	wget "https://github.com/PowerDNS-Admin/PowerDNS-Admin/archive/refs/tags/v$POWERDNS_ADMIN_VER.tar.gz" \
		-O "PowerDNS-Admin-$POWERDNS_ADMIN_VER.tar.gz"; \
	tar -zxvf "PowerDNS-Admin-$POWERDNS_ADMIN_VER.tar.gz"

RUN set -eux; \
	cd build; \
	cd "PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	\
	true "PowerDNS Admin Dockerfile Check"; \
	dockerfile_sha256=$(sha256sum docker/Dockerfile | awk '{print $1}'); \
	dockerconfig_sha256=$(sha256sum configs/docker_config.py | awk '{print $1}'); \
	if [ "$dockerfile_sha256" != "2343ed09ef17a7043731288ab9647f89802a4fb7077300f9cb62f30d8a87ae34" ]; then \
		echo "ERROR ERROR ERROR - Check changes in the docker/Dockerfile!\nHASH: $dockerfile_sha256"; \
		false; \
	fi; \
	if [ "$dockerconfig_sha256" != "758ddb0b5789dad5755689cd5dfdb3c3f2dede557a10997046b550cfda1da1e3" ]; then \
		echo "ERROR ERROR ERROR - Check changes in the config/docker_config.py!\nHASH: $dockerfile_sha256"; \
		false; \
	fi; \
	true "Patch PowerDNS requirements.txt"; \
	grep "psycopg2==2.9.5" requirements.txt; \
	sed -i -e 's/psycopg2==2.9.5/psycopg2~=2.9.5/' requirements.txt; \
	true "PowerDNS Admin Python Requirements"; \
	python -m venv --system-site-packages /app/.venv; \
	. /app/.venv/bin/activate; \
	pip install --upgrade pip; \
	pip install --no-cache --use-pep517 -r requirements.txt

RUN set -eux; \
	true "Build PowerDNS Admin Assets"; \
	cd "build/PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	yarn install --pure-lockfile --production; \
    yarn cache clean; \
    sed -i -r -e "s|'rcssmin',\s?'cssrewrite'|'rcssmin'|g" powerdnsadmin/assets.py; \
	. /app/.venv/bin/activate; \
    FLASK_APP="$PWD"/powerdnsadmin/__init__.py flask assets build

RUN set -eux; \
	true "Build PowerDNS Admin Assets"; \
	cd "build/PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	mv powerdnsadmin/static tmp.static; \
    mkdir -p powerdnsadmin/static/node_modules; \
    cp -rv tmp.static/generated powerdnsadmin/static; \
    cp -rv tmp.static/assets powerdnsadmin/static; \
    cp -rv tmp.static/img powerdnsadmin/static; \
	find tmp.static/node_modules -name 'webfonts' -exec cp -rv {} powerdnsadmin/static \; ; \
    find tmp.static/node_modules -name 'fonts' -exec cp -rv {} powerdnsadmin/static \; ; \
    find tmp.static/node_modules/icheck/skins/square -name '*.png' -exec cp -rv {} powerdnsadmin/static/generated \;

RUN set -eux; \
	cd "build/PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	true "Symlink PowerDNS Admin session directory"; \
	ln -s /run/gunicorn/flask_session /app/flask_session; \
	true "Copy PowerDNS Admin background update scripts"; \
	cp update_accounts.py update_zones.py /app

RUN set -eux; \
	true "Create PowerDNS Admin Flask Asset Configuration"; \
	cd "build/PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
	{ \
		echo "from flask_assets import Environment"; \
		echo "assets = Environment()"; \
		echo "assets.register('js_login', 'generated/login.js')"; \
		echo "assets.register('js_validation', 'generated/validation.js')"; \
		echo "assets.register('css_login', 'generated/login.css')"; \
		echo "assets.register('js_main', 'generated/main.js')"; \
		echo "assets.register('css_main', 'generated/main.css')"; \
    } > powerdnsadmin/assets.py

RUN set -eux; \
	true "Copy PowerDNS Admin"; \
	cd "build/PowerDNS-Admin-$POWERDNS_ADMIN_VER"; \
    cp -r migrations/ powerdnsadmin/ run.py /app/; \
	ln -s /app/powerdnsadmin/static /app/static



FROM registry.conarx.tech/containers/nginx-gunicorn/3.17


ARG VERSION_INFO=
LABEL org.opencontainers.image.authors   "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   "3.17"
LABEL org.opencontainers.image.base.name "registry.conarx.tech/containers/nginx-gunicorn/3.17"


# Set nginx health check URI
ENV NGINX_HEALTHCHECK_URI=http://localhost/login


COPY --from=builder /app /app

# Copy in our configuration manager
COPY app/powerdnsadmin/docker_config.py /app/powerdnsadmin/docker_config.py


RUN set -eux; \
	true "PowerDNS Admin Requirements"; \
	apk add --no-cache \
		mariadb-client \
		mariadb-connector-c \
		libldap \
		postgresql-client \
		py3-dotenv \
		py3-psycopg2 \
		xmlsec \
		tzdata; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


RUN set -eux; \
	true "Remove nginx-gunicorn Test"; \
	rm -f \
		/usr/local/share/flexible-docker-containers/pre-init-tests.d/46-nginx-gunicorn.sh \
		/usr/local/share/flexible-docker-containers/tests.d/46-nginx-gunicorn.sh \
		/usr/local/share/flexible-docker-containers/tests.d/44-nginx.sh


# Gunicorn
COPY etc/cron.d/powerdnsadmin /etc/cron.d
COPY usr/local/bin/powerdnsadmin-hashpw /usr/local/bin
COPY usr/local/sbin/powerdnsadmin-update /usr/local/sbin
COPY usr/local/sbin/powerdnsadmin-upgrade /usr/local/sbin
COPY usr/local/share/flexible-docker-containers/init.d/48-powerdnsadmin.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/48-powerdnsadmin.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/pre-exec-tests.d/48-powerdnsadmin.sh /usr/local/share/flexible-docker-containers/pre-exec-tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/44-powerdnsadmin.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/48-powerdnsadmin.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/99-powerdnsadmin.sh /usr/local/share/flexible-docker-containers/tests.d
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	chown root:root \
		/usr/local/bin/powerdnsadmin-hashpw \
		/usr/local/sbin/powerdnsadmin-update \
		/usr/local/sbin/powerdnsadmin-upgrade; \
	chmod 0755 \
		/usr/local/bin/powerdnsadmin-hashpw \
		/usr/local/sbin/powerdnsadmin-update \
		/usr/local/sbin/powerdnsadmin-upgrade; \
	fdc set-perms
