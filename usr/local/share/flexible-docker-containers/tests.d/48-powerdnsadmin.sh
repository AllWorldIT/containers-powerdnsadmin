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


pdnsa_api_basic() {
	local method=$1
	local endpoint=$2
	local data=$3
	shift 3

	local args_before=()
	local args_after=()
	if [ -n "$data" ]; then
		# Don't specify -X POST as this is default when --data is provided
		if [ "$method" != "POST" ]; then
			args_before+=("-X" "$method")
		fi
		args_after+=("--data" "$data")
	fi

	echo -- "RUNNING => " curl -L --trace-ascii - \
		-H "Content-Type: application/json" \
		-H "Authorization: Basic $TEST_API_BASICAUTH" \
		"${args_before[@]}" \
		"http://localhost/$endpoint" \
		"${args_after[@]}" \
		"$@"

	curl -L --trace-ascii - \
		-H "Content-Type: application/json" \
		-H "Authorization: Basic $TEST_API_BASICAUTH" \
		"${args_before[@]}" \
		"http://localhost/$endpoint" \
		"${args_after[@]}" \
		"$@"

	return $?
}

pdnsa_api() {
	local method=$1
	local endpoint=$2
	local data=$3
	shift 3

	local args_before=()
	local args_after=()
	if [ -n "$data" ]; then
		# Don't specify -X POST as this is default when --data is provided
		if [ "$method" != "POST" ]; then
			args_before+=("-X" "$method")
		fi
		args_after+=("--data" "$data")
	fi

	echo -- "RUNNING => " curl -L --trace-ascii - \
		-H "Content-Type: application/json" \
		-H "X-API-KEY: $TEST_API_KEY" \
		"${args_before[@]}" \
		"http://localhost/$endpoint" \
		"${args_after[@]}" \
		"$@"

	curl -L --trace-ascii - \
		-H "Content-Type: application/json" \
		-H "X-API-KEY: $TEST_API_KEY" \
		"${args_before[@]}" \
		"http://localhost/$endpoint" \
		"${args_after[@]}" \
		"$@"

	return $?
}



#
# Test Basic Auth IPv4
#



fdc_test_start powerdnsadmin "Check PowerDNS Admin can create a zone with Basic Auth using IPv4..."
if ! pdnsa_api_basic POST api/v1/pdnsadmin/zones '{"name": "basic-ipv4.example.com.", "kind": "NATIVE", "nameservers": ["ns1.basic-ipv4.example.com."]}' --ipv4 --output test.zone.out; then
	fdc_test_fail powerdnsadmin "Failed to create a zone with Basic Auth using IPv4"
	false
fi

if ! grep basic-ipv4.example.com test.zone.out; then
	fdc_test_fail powerdnsadmin "Results from create zone does not match what it should be with Basic Auth using IPv4"
	cat test.zone.out
	false
fi

fdc_test_pass powerdnsadmin "PowerDNS Admin zone created with Basic Auth using IPv4"


fdc_test_start powerdnsadmin "Testing DNS query result from Basic Auth added zone using IPv4"
if ! dig NS basic-ipv4.example.com @powerdns | grep ns1.basic-ipv4.example.com; then
	fdc_test_fail powerdnsadmin "Failed to get correct DNS query reply from Basic Auth added zone using IPv4"
	dig NS basic-ipv4.example.com @powerdns
	false
fi
fdc_test_pass powerdnsadmin "Correct DNS query reply from Basic Auth added zone using IPv4"



#
# Test API Auth IPv4
#



fdc_test_start powerdnsadmin "Check PowerDNS Admin can create a zone with API Auth using IPv4..."
if ! pdnsa_api POST api/v1/servers/localhost/zones '{"name": "api-ipv4.example.com.", "kind": "NATIVE", "nameservers": ["ns1.api-ipv4.example.com."]}' --ipv4 --output test.zone.out; then
	fdc_test_fail powerdnsadmin "Failed to create a zone with API Auth using IPv4"
	false
fi

if ! grep api-ipv4.example.com test.zone.out; then
	fdc_test_fail powerdnsadmin "Results from create zone does not match what it should be with API Auth using IPv4"
	cat test.zone.out
	false
fi

fdc_test_pass powerdnsadmin "PowerDNS Admin zone created with API Auth using IPv4"


fdc_test_start powerdnsadmin "Testing DNS query result from API Auth added zone using IPv4"
if ! dig NS api-ipv4.example.com @powerdns | grep ns1.api-ipv4.example.com; then
	fdc_test_fail powerdnsadmin "Failed to get correct DNS query reply from API Auth added zone using IPv4"
	dig NS api-ipv4.example.com @powerdns
	false
fi
fdc_test_pass powerdnsadmin "Correct DNS query reply from API Auth added zone using IPv4"



# Return if we don't have IPv6 support
if [ -z "$(ip -6 route show default)" ]; then
	fdc_test_alert powerdns "Not running IPv6 tests due to no IPv6 default route"
	ip -6 route show default
	return
fi



#
# Test Basic Auth IPv6
#



fdc_test_start powerdnsadmin "Check PowerDNS Admin can create a zone with Basic Auth using IPv6..."
if ! pdnsa_api_basic POST api/v1/pdnsadmin/zones '{"name": "basic-ipv6.example.com.", "kind": "NATIVE", "nameservers": ["ns1.basic-ipv6.example.com."]}' --ipv6 --output test.zone.out; then
	fdc_test_fail powerdnsadmin "Failed to create a zone with Basic Auth using IPv6"
	false
fi

if ! grep basic-ipv6.example.com test.zone.out; then
	fdc_test_fail powerdnsadmin "Results from create zone does not match what it should be with Basic Auth using IPv6"
	cat test.zone.out
	false
fi

fdc_test_pass powerdnsadmin "PowerDNS Admin zone created with Basic Auth using IPv6"


fdc_test_start powerdnsadmin "Testing DNS query result from Basic Auth added zone using IPv6"
if ! dig NS basic-ipv6.example.com @powerdns | grep ns1.basic-ipv6.example.com; then
	fdc_test_fail powerdnsadmin "Failed to get correct DNS query reply from Basic Auth added zone using IPv6"
	dig NS basic-ipv6.example.com @powerdns
	false
fi
fdc_test_pass powerdnsadmin "Correct DNS query reply from Basic Auth added zone using IPv6"



#
# Test API Auth IPv6
#



fdc_test_start powerdnsadmin "Check PowerDNS Admin can create a zone with API Auth using IPv6..."
if ! pdnsa_api POST api/v1/servers/localhost/zones '{"name": "api-ipv6.example.com.", "kind": "NATIVE", "nameservers": ["ns1.api-ipv6.example.com."]}' --ipv6 --output test.zone.out; then
	fdc_test_fail powerdnsadmin "Failed to create a zone with API Auth using IPv6"
	false
fi

if ! grep api-ipv6.example.com test.zone.out; then
	fdc_test_fail powerdnsadmin "Results from create zone does not match what it should be with API Auth using IPv6"
	cat test.zone.out
	false
fi

fdc_test_pass powerdnsadmin "PowerDNS Admin zone created with API Auth using IPv6"


fdc_test_start powerdnsadmin "Testing DNS query result from API Auth added zone using IPv6"
if ! dig NS api-ipv6.example.com @powerdns | grep ns1.api-ipv6.example.com; then
	fdc_test_fail powerdnsadmin "Failed to get correct DNS query reply from API Auth added zone using IPv6"
	dig NS api-ipv6.example.com @powerdns
	false
fi
fdc_test_pass powerdnsadmin "Correct DNS query reply from API Auth added zone using IPv6"
