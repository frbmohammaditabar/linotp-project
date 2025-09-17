# LinOTP3 Docker Compose Setup
Author: Fariba Mohammaditabar
Last Update: 2025 Sep 17

This project provides a complete environment for **LinOTP3** with PostgreSQL database, Self-Service Portal, and FreeRADIUS.

## Services Overview

### 1. LinOTP3
- **Container Name:** `linotp3`
- **Image:** `linotp3`
- **Port:** `4443:5000`
- **Environment Variables:**
  - `LINOTP_ADMIN_PASSWORD`: Admin password for LinOTP
  - `LINOTP_DATABASE_URI`: PostgreSQL connection URI
  - `LINOTP_LOG_LEVEL`: Log level (DEBUG for development)
  - `LINOTP_SITE_ROOT_REDIRECT`: Default redirect path
  - `LINOTP_SESSION_COOKIE_SECURE`: Set to `false` for non-HTTPS testing
- **Features:**  
  - Persistent data stored in `linotp_data` volume.
  - Depends on `linotp-db` service.

### 2. Self-Service Portal
- **Container Name:** `selfservice`
- **Image:** `selfservice`
- **Port:** `443:80`
- **Features:**  
  - Portal for users to manage their OTP tokens.
  - Custom UI files are mounted from `/root/linotp3/portal/`.
  - `URL_PATH` environment variable sets the portal path.

### 3. FreeRADIUS
- **Container Name:** `freeradius`
- **Image:** `build_freeradius`
- **Ports:**
  - `1814:1812/udp`  
  - `1815:1813/udp`
- **Features:**  
  - RADIUS service for LinOTP token authentication.
  - Configuration files and Perl modules are mounted from the host.

### 4. PostgreSQL Database
- **Container Name:** `linotp-db`
- **Image:** `postgres:latest`
- **Features:**  
  - LinOTP database stored in `pg_data` volume.
  - Environment variables include database name, user, and password.

## Getting Started

1. Make sure **Docker** and **Docker Compose** are installed.
2. Clone this repository or copy the `docker-compose.yml` file.
3. Start the services:

```bash
docker-compose up -d
Access the services:

LinOTP Admin UI: https://<host>:4443/manage/

Self-Service Portal: https://<host>/selfservice/

Notes
Data is persisted in Docker volumes linotp_data and pg_data.

FreeRADIUS ports 1812/udp and 1813/udp are mapped to host ports 1814 and 1815.

For production, update passwords and consider enabling secure cookies (LINOTP_SESSION_COOKIE_SECURE=true).

Volumes
linotp_data: stores LinOTP persistent data

pg_data: stores PostgreSQL database data

pgsql
```





# LinOTP3 Docker Compose 🚀

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)

A lightweight Docker Compose setup for **LinOTP3**, including:

- LinOTP3 Admin UI
- Self-Service Portal
- FreeRADIUS
- PostgreSQL backend

---

## Quickstart

```bash
# Clone repository or copy docker-compose.yml
git clone <repo-url>
cd <repo-dir>

# Start all services
docker-compose up -d

# View running containers
docker-compose ps
Access Services
Service	URL / Port
LinOTP Admin UI	https://<host>:4443/manage/
Self-Service Portal	https://<host>/selfservice/
FreeRADIUS RADIUS Auth	udp://<host>:1814 (Auth)
udp://<host>:1815 (Acct)
```
## Environment Variables
LINOTP_ADMIN_PASSWORD – Admin password for LinOTP

LINOTP_DATABASE_URI – PostgreSQL URI (e.g., postgres://user:pass@linotp-db/linotp_db)

LINOTP_LOG_LEVEL – Log verbosity (DEBUG recommended for testing)

LINOTP_SITE_ROOT_REDIRECT – Default redirect path

LINOTP_SESSION_COOKIE_SECURE – Set true in production

## Volumes
linotp_data – LinOTP persistent data

pg_data – PostgreSQL database data

## Notes
Ensure Docker and Docker Compose are installed.

FreeRADIUS ports are remapped: host 1814/udp → container 1812/udp and 1815/udp → container 1813/udp.

For production, always change default passwords and enable secure cookies.

Example Commands
```bash
# View LinOTP logs
docker-compose logs -f linotp3

# Restart a single service
docker-compose restart selfservice

# Stop all services
docker-compose down
```
