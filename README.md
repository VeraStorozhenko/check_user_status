# Check User Status API

Rails API service for evaluating a user's ban status from IDFA, Cloudflare country, rooted-device signal, and VPNAPI IP intelligence.

## Stack

- Ruby 3.3.0
- Rails 7.2.x API-only app
- PostgreSQL
- Redis
- RSpec, FactoryBot, WebMock

## Endpoint

`POST /v1/user/check_status`

Headers:

```http
Content-Type: application/json
CF-IPCountry: US
```

Request:

```json
{
  "idfa": "8264148c-be95-4b2b-b260-6ee98dd53bf6",
  "rooted_device": false
}
```

Success response:

```json
{
  "ban_status": "not_banned"
}
```

`ban_status` can currently be `not_banned` or `banned`.

Validation error:

```json
{
  "error": "idfa parameter is required"
}
```

## Ban Rules

A user is banned when any of these checks fail:

- `CF-IPCountry` is missing or not present in the Redis `country_whitelist` set.
- `rooted_device` is truthy.
- VPNAPI reports the request IP as VPN, proxy, or Tor.

If VPNAPI is unavailable, returns a non-success response, times out, or no API key is configured, the VPN check fails open and the request continues as passed. VPNAPI responses are cached in Redis for 24 hours under `vpnapi:<ip>`.

Existing banned users skip the check chain and immediately return `banned`. Existing `not_banned` users are checked again on every request. Integrity logs are written when a user is created or when the user's `ban_status` changes.

## Setup

Install dependencies:

```bash
bundle install
```

Prepare the database:

```bash
bin/rails db:create db:migrate
```

Start Redis locally, then configure environment variables as needed:

```bash
export REDIS_URL=redis://localhost:6379/1
export VPN_API_KEY=your_vpnapi_key
```

`VPN_API_KEY` is optional for local development because the VPN check fails open when it is absent.

Run the API:

```bash
bin/rails server
```

Example request:

```bash
curl -X POST http://localhost:3000/v1/user/check_status \
  -H "Content-Type: application/json" \
  -H "CF-IPCountry: US" \
  -d '{"idfa":"8264148c-be95-4b2b-b260-6ee98dd53bf6","rooted_device":false}'
```

## Tests and Quality

Run the test suite:

```bash
bundle exec rspec
```

Run RuboCop:

```bash
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bundle exec rubocop
```

Current verification:

- RSpec: 24 examples, 0 failures
- RuboCop: 39 files inspected, no offenses detected

## Notes

The assignment asks for Rails 8. This implementation currently uses Rails 7.2.x, matching the checked-in application and lockfile. Upgrading to Rails 8 should be handled as a separate dependency/runtime change.
