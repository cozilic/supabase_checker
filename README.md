# Supabase Checker

A fast and lightweight Supabase health checker with Gotify notifications.

`supabase_checker` monitors one or more Supabase REST endpoints and sends alerts when a project goes down. It also sends a recovery notification when the project comes back online.

The project is designed to be simple, Docker-friendly, and easy to self-host.

---

## Features

* Monitor multiple Supabase projects/endpoints
* Uses simple HTTP status checks
* Supports custom timeout, retries, and retry delay
* Sends DOWN alerts through Gotify
* Sends UP/recovery notifications when a service comes back online
* Stores state locally to avoid repeated spam notifications
* Runs in Docker using a lightweight Alpine image
* Checks every 5 minutes by default

---

## How it works

The checker reads all projects from `config.env`.

Each project is defined like this:

```env
name|url|apikey
```

Multiple projects are separated with `;`.

Example:

```env
PROJECTS="main-api|https://project1.supabase.co/rest/v1/test?select=1&limit=1|key1;auth-api|https://project2.supabase.co/rest/v1/test?select=1&limit=1|key2"
```

For each project, the script:

1. Sends a request to the configured Supabase REST URL.
2. Adds the Supabase API key using the `apikey` header.
3. Treats HTTP `2xx` and `3xx` responses as `UP`.
4. Retries failed checks based on your config.
5. Marks the project as `DOWN` if all retries fail.
6. Sends a Gotify notification only when the state changes.
7. Sends a recovery notification when the project becomes available again.

---

## Requirements

* Docker
* A Gotify server
* One or more Supabase REST endpoints
* A Supabase API key for each endpoint

For most checks, use an `anon` key or a limited key. Avoid using powerful service-role keys unless you really need them.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/cozilic/supabase_checker.git
cd supabase_checker
```

Create your config file:

```bash
cp config.env.example config.env
```

Edit `config.env`:

```bash
nano config.env
```

---

## Configuration

Example `config.env`:

```env
# =========================
# PROJECTS
# Format:
# name|url|apikey;name2|url2|apikey2
# =========================

PROJECTS="main-api|https://your-project.supabase.co/rest/v1/health?select=1&limit=1|your-api-key"

# =========================
# GOTIFY
# =========================

GOTIFY_URL="https://your-gotify-instance/message"
GOTIFY_TOKEN="your-gotify-token"

# =========================
# BEHAVIOR
# =========================

TIMEOUT=10
RETRIES=3
RETRY_DELAY=5
```

### Config values

| Variable       | Description                                     |
| -------------- | ----------------------------------------------- |
| `PROJECTS`     | List of Supabase endpoints to monitor           |
| `GOTIFY_URL`   | Gotify message endpoint                         |
| `GOTIFY_TOKEN` | Gotify application token                        |
| `TIMEOUT`      | Max time in seconds for each request            |
| `RETRIES`      | Number of retry attempts before marking as DOWN |
| `RETRY_DELAY`  | Delay in seconds between retries                |

---

## Project format

Each project uses this format:

```env
name|url|apikey
```

Example with two projects:

```env
PROJECTS="main-api|https://project1.supabase.co/rest/v1/test?select=1&limit=1|key1;auth-api|https://project2.supabase.co/rest/v1/test?select=1&limit=1|key2"
```

Make sure:

* Each project has a unique name.
* The URL points to a valid Supabase REST endpoint.
* The API key has permission to access the endpoint.
* Projects are separated with `;`.
* The project fields are separated with `|`.

---

## Run with Docker

Build the image:

```bash
docker build -t supabase-checker .
```

Run the container:

```bash
docker run -d \
  --name supabase-checker \
  --restart unless-stopped \
  -v "$(pwd)/config.env:/app/config.env:ro" \
  -v "$(pwd)/state:/app/state" \
  supabase-checker
```

The container will run the checker every 5 minutes.

---

## Docker Compose example

Create a `docker-compose.yml` file:

```yaml
services:
  supabase-checker:
    build: .
    container_name: supabase-checker
    restart: unless-stopped
    volumes:
      - ./config.env:/app/config.env:ro
      - ./state:/app/state
```

Start it:

```bash
docker compose up -d
```

View logs:

```bash
docker logs -f supabase-checker
```

Stop it:

```bash
docker compose down
```

---

## Gotify setup

1. Create an application in Gotify.
2. Copy the application token.
3. Add the token to `GOTIFY_TOKEN`.
4. Set `GOTIFY_URL` to your Gotify message endpoint.

Example:

```env
GOTIFY_URL="https://gotify.example.com/message"
GOTIFY_TOKEN="Axxxxxxxxxxxxxxxxxxxx"
```

---

## Notifications

When a project goes down, Gotify receives a message like:

```text
Supabase Alert: main-api
Supabase project DOWN: main-api
https://your-project.supabase.co/rest/v1/health?select=1&limit=1
```

When the project comes back online, Gotify receives a recovery message:

```text
Supabase Recovery: main-api
Supabase project UP again: main-api
```

---

## State handling

The checker stores the latest known state for each project in:

```text
/app/state
```

This prevents repeated DOWN notifications while a project is already down.

Recommended Docker volume:

```bash
-v "$(pwd)/state:/app/state"
```

Without this volume, state may be lost when the container is recreated.

---

## Security notes

Do not commit your real `config.env` file.

This repository ignores:

```text
config.env
state/
```

Keep your Supabase API keys and Gotify token private.

If you build and publish Docker images, be careful because the current Dockerfile expects `config.env` during build. For public images, consider changing the Dockerfile so the config is only mounted at runtime.

---

## Troubleshooting

### I get DOWN even though Supabase is online

Check that:

* The REST URL is correct.
* The table or endpoint exists.
* The API key has access.
* Row Level Security is not blocking the request.
* The endpoint returns HTTP `2xx` or `3xx`.

### Gotify does not receive notifications

Check that:

* `GOTIFY_URL` ends with `/message`.
* `GOTIFY_TOKEN` is a valid application token.
* The Gotify server is reachable from the container.
* The container logs do not show a Gotify error.

View logs:

```bash
docker logs -f supabase-checker
```

### Config changes are not applied

Restart the container after editing `config.env`:

```bash
docker restart supabase-checker
```

If you baked the config into the image during build, rebuild the image:

```bash
docker build -t supabase-checker .
docker restart supabase-checker
```

---

## Roadmap ideas

* Add Discord webhook support
* Add Telegram notifications
* Add Slack notifications
* Add health check summary logs
* Add custom check interval through config
* Add Docker image publishing through GitHub Actions
* Add support for checking multiple headers per project

---

## License

No license has been added yet.

Consider adding a license file if you want others to use, modify, or contribute to the project.
