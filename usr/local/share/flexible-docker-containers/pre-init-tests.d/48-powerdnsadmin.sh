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


# We need 'dig' to do the actual DNS query testing
apk add bind-tools


if [ "$FDC_CI" = "sqlite" ]; then
	mkdir /app/data
	chown root:gunicorn /app/data
	chmod 0770 /app/data

	export PDNSA_SQLALCHEMY_DATABASE_URI=sqlite:////app/data/pdnsa.db
fi

export PDNSA_CAPTCHA_SESSION_KEY=citest
# shellcheck disable=SC2016
export PDNSA_SALT='$2b$12$dhYD/COb6nQHttdnpBfx3u'
export PDNSA_SECRET_KEY=citest
export PDNSA_LOG_LEVEL=debug

export PDNSA_ADMIN_USERNAME=admin
export PDNSA_ADMIN_PASSWORD=admin

export TEST_API_KEY=QkhwbmZqblJKTlB3M3I0
# shellcheck disable=SC2155
export TEST_API_BASICAUTH=$(echo -n "admin:admin" | base64)
