# docker-mariadb-snapshot
<p align="center">
  <img src="docs/images/logo.png" alt="docker-mariadb-snapshot logo">
</p>

[![CI](https://github.com/JacobSanford/docker-mariadb-snapshot/actions/workflows/ci.yml/badge.svg)](https://github.com/JacobSanford/docker-mariadb-snapshot/actions/workflows/ci.yml)
A Docker container that performs periodic MariaDB/MySQL database snapshots with rotation using rsnapshot. Designed for use alongside a MariaDB/MySQL container or server.

## Documentation

Read the [Full documentation](https://jacobsanford.github.io/docker-mariadb-snapshot/latest/)

- **[Quick Start Guide](https://jacobsanford.github.io/docker-mariadb-snapshot/latest/quickstart)** - Get started in 5 minutes
- **[Configuration Reference](https://jacobsanford.github.io/docker-mariadb-snapshot/latest/configuration)** - Complete environment variable guide
- **[Docker Compose Examples](https://jacobsanford.github.io/docker-mariadb-snapshot/latest/docker-compose)** - Sample configurations for all modes
- **[Kubernetes Deployment](https://jacobsanford.github.io/docker-mariadb-snapshot/latest/kubernetes)** - CronJob configurations
- **[Running Tests](https://jacobsanford.github.io/docker-mariadb-snapshot/latest/running-tests)** - Developer testing guide
## Quick Start

### Docker CLI
Run a simple snapshot:

```bash
docker run --rm \
  -e DB_HOSTNAME=mysql.example.com \
  -e DB_USER_NAME=snapshot_user \
  -e DB_USER_PASSWORD=secure_password \
  -e DB_DATABASES=myapp \
  -v /output/path:/data \
  jacobsanford/docker-mariadb-snapshot:1.x hourly
```

### Docker Compose
Add this service to your `docker-compose.yml`:

```yaml
services:
  [...]

  mariadb-snapshot:
    image: jacobsanford/docker-mariadb-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: mysql
      DB_DATABASE: myapp
      DB_USER_NAME: root
      DB_USER_PASSWORD: changeme
    volumes:
      - ./snapshots:/data
```

Run snapshot: `docker compose run --rm mariadb-snapshot daily`

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
