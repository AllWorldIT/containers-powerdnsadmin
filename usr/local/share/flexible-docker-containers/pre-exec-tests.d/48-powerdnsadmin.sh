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


if [ "$FDC_CI" = "mysql" ]; then
	export MYSQL_PWD="$MYSQL_PASSWORD"

	fdc_notice "Setting up PowerDNS Admin data for MySQL tests"

	cat <<EOF | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE"
INSERT INTO apikey (\`key\`, description, role_id) VALUES ("\$2b\$12\$dhYD/COb6nQHttdnpBfx3uiyeoyZND2eMYyIubEwTl19CKHocxpf6", "Test Key", 1);
EOF

	unset MYSQL_PWD
fi



if [ "$FDC_CI" = "postgres" ]; then
	export PGPASSWORD="$POSTGRES_PASSWORD"

	fdc_notice "Setting up PowerDNS Admin data for PostgreSQL tests"

	cat <<EOF | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -w "$POSTGRES_DATABASE" -v ON_ERROR_STOP=ON
INSERT INTO apikey ("key", description, role_id) VALUES ('\$2b\$12\$dhYD/COb6nQHttdnpBfx3uiyeoyZND2eMYyIubEwTl19CKHocxpf6', 'Test Key', 1);
EOF

	unset PGPASSWORD
fi
