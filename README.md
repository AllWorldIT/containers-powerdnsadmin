[![pipeline status](https://gitlab.conarx.tech/containers/powerdnsadmin/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/powerdnsadmin/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/powerdnsadmin) - [GitHub Mirror](https://github.com/AllWorldIT/containers-powerdnsadmin)

This is the Conarx Containers PowerDNS Admin image, it provides the PowerDNS Admin application used for managing PowerDNS servers.

Features include:
- Automatic database initialization
- Automatic upgrade on new version
- Initial admin user setup
- Background updates



# Mirrors

|  Provider  |  Repository                                   |
|------------|-----------------------------------------------|
| DockerHub  | allworldit/powerdnsadmin                      |
| Conarx     | registry.conarx.tech/containers/powerdnsadmin |



# Conarx Containers

All our Docker images are part of our Conarx Containers product line. Images are generally based on Alpine Linux and track the
Alpine Linux major and minor version in the format of `vXX.YY`.

Images built from source track both the Alpine Linux major and minor versions in addition to the main software component being
built in the format of `vXX.YY-AA.BB`, where `AA.BB` is the main software component version.

Our images are built using our Flexible Docker Containers framework which includes the below features...

- Flexible container initialization and startup
- Integrated unit testing
- Advanced multi-service health checks
- Native IPv6 support for all containers
- Debugging options
- Automatic PowerDNS API configuration



# Community Support

Please use the project [Issue Tracker](https://gitlab.conarx.tech/containers/powerdnsadmin/-/issues).



# Commercial Support

Commercial support for all our Docker images is available from [Conarx](https://conarx.tech).

We also provide consulting services to create and maintain Docker images to meet your exact needs.



# Environment Variables

Additional environment variables are available from...
* [Conarx Containers Nginx Gunicorn image](https://gitlab.conarx.tech/containers/nginx-gunicorn)
* [Conarx Containers Nginx image](https://gitlab.conarx.tech/containers/nginx)
* [Conarx Containers Postfix image](https://gitlab.conarx.tech/containers/postfix)
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine)


# Mandatory Environment Variables


## PDNSA_CAPTCHA_SESSION_KEY

Mandatory. Capatcha session key, this is a random string and must be set.


## PDNSA_SALT

Mandatory. Salt used for API keys. Changing this will invalidate all API keys.

Use for API keys and can be generated with the below command...
```bash
python -c 'import bcrypt; print(bcrypt.gensalt().decode("UTF-8"))'
```

NB: If you are using the salt in an environment: in a docker-compose file, you will need to escape each '$' using '$$'.


## PDNSA_SECRET_KEY

Mandatory. Secret key used for encrypting various data.


## PDNSA_ADMIN_USERNAME

Initial admin username to create. This only has an effect if there is no users defined.


## PDNSA_ADMIN_PASSWORD

Initial admin user password. This only has an effect if there is no users defined.



# PowerDNS Backend Configuration Variables

If both `PDNS_API_URL` and `PDNS_API_KEY` are specified the configuration for the PowerDNS Backend will be updated.


## POWERDNS_API_URL

PowerDNS API URL.


## POWERDNS_API_KEY

PowerDNS API key.


## POWERDNS_VERSION

PowerDNS version. At present (2023) it is only used to determine if the server is newer than version 4.1.1.



# MySQL Backend Environment Variables


## MYSQL_HOST

MySQL server hostname.


## MYSQL_DATABASE

Database to connect to.


## MYSQL_USER

Username to use to connect with.


## MYSQL_PASSWORD

User password to use when connecting to the database.



# PostgreSQL Backend Environment Variables


## POSTGRES_HOST

Database server hostname.


## POSTGRES_DATABASE

Database to connect to.


## POSTGRES_USER

Username to use to connect with.


## POSTGRES_USER_PASSWORD

User password to use when connecting to the database.



# Exposed Ports

Postfix port 25 is exposed by the [Conarx Containers Postfix image](https://gitlab.conarx.tech/containers/postfix) layer.

Nginx port 80 is exposed by the [Conarx Containers Nginx image](https://gitlab.conarx.tech/containers/nginx) layer.



# Files & Directories

Configuration for Nginx can also be overridden, see the source for this containers Nginx configuration and
[Conarx Containers Nginx image](https://gitlab.conarx.tech/containers/nginx) for more details.


## /etc/powerdnsadmin/config.env

PowerDNS Admin configuration in ENV format.

## /run/gunicorn/flask_session

PowerDNS Admin sessions if using filesystem based sessions.



# Health Checks

Health checks are done by the underlying
[Conarx Containers Nginx image](https://gitlab.iitsp.com/allworldit/docker/nginx/README.md).
