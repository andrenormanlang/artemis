# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

- Ruby version

- System dependencies

- Configuration

- Database creation

- Database initialization

- How to run the test suite

- Services (job queues, cache servers, search engines, etc.)

- Deployment instructions

- ...

## How to run the daily lunar email

To enqueue the daily lunar email job immediately:

    bin/rails cron:daily_lunar_email

Or with rake/bundle in any environment:

    bundle exec rake cron:daily_lunar_email RAILS_ENV=production

Notes:

- The mailer and job use the Rails `ActionMailer` and `ActiveJob` settings in your environment files.
- If you want a production scheduler, run Sidekiq with a scheduler (config/sidekiq_scheduler.yml and config/sidekiq.yml exist) or use system cron / Windows Task Scheduler to run the rake task daily.
- The job now guards against duplicate sends per user for the same Europe/Stockholm date, so overlapping scheduler sources will not send two copies.

GitHub Actions scheduled run

- The repository includes a workflow at `.github/workflows/daily_lunar_email.yml` which runs the daily email.
- Schedule: the workflow is configured to trigger daily around **21:30 Europe/Stockholm** (DST-safe). Because GitHub cron uses UTC, the workflow cron is set to `30 19,20 * * *` (UTC) to cover DST transitions.
- Tolerance: the workflow includes a local-time check and allows a **±15 minute** window around 21:30 to avoid missing runs due to minute-level scheduling jitter.
- Manual run / force: the workflow supports a `workflow_dispatch` input named `force`. To force a run regardless of local time set `force` to `true` in the Actions UI, or run:

```bash
gh workflow run daily_lunar_email.yml --ref main -f force=true
```

- Troubleshooting: if you do not receive email:
  - Open the Actions run logs and look for the `Check local time` output and the rake task logs (`Starting DailyLunarEmailJob...`, `DailyLunarEmailJob complete.`).
  - Verify GitHub repository Secrets (Settings → Secrets → Actions) contain: `DATABASE_URL`, `RAILS_MASTER_KEY`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `APP_HOST`, `DAILY_LUNAR_API_URL`, `ASTRO_API_KEY`, and `REDIS_URL`.
  - If the workflow was skipped due to time mismatch, re-run with `force=true` as shown above.

## Sidekiq & Redis

This project supports using Sidekiq for background processing and scheduled jobs.

1. Add Redis and Sidekiq secrets

- Provision a Redis instance (managed options: Upstash, Redis Cloud, AWS ElastiCache, DigitalOcean Managed Redis). Copy the connection URL and add it to your environment as `REDIS_URL` (example: `redis://:password@hostname:6379/0`).
- In GitHub repo Settings → Secrets → Actions add `REDIS_URL` along with `DATABASE_URL`, `RAILS_MASTER_KEY`, and SMTP secrets.

2. Running Sidekiq locally

Set `REDIS_URL` locally (e.g., export REDIS_URL=redis://localhost:6379/0) and start Sidekiq:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

3. Running Sidekiq in production

- Run a worker process on your host or platform (Procfile contains a `worker` entry). Example (Heroku/Render): `worker: bundle exec sidekiq -C config/sidekiq.yml`.
- Ensure `REDIS_URL` is set in your environment/secrets. Sidekiq will use `ENV['REDIS_URL']`.

4. Scheduling jobs

- This repo includes `config/sidekiq_scheduler.yml` and `config/sidekiq.yml` — when Sidekiq starts the initializer will load the cron schedule (requires `sidekiq-cron`). Configure the cron there (they currently contain `daily_lunar_email`).

If you'd like, I can provision a small Upstash Redis instance for you and add the required secrets to the repo, or add Sidekiq deployment instructions for your hosting provider.

## Using Upstash (example)

If you used Upstash to create a free Redis instance, you'll see two connection types in the dashboard: a REST API and a Redis (CLI/TLS) URL. Sidekiq requires the Redis URL (RESP/TLS) as `REDIS_URL`.

Example (do NOT commit this value; add it to GitHub Secrets):

    REDIS_URL=rediss://default:<UPSTASH_PASSWORD>@adapting-sunbeam-80687.upstash.io:6379/0

How to set the secret in GitHub:

1. Go to your repository → Settings → Secrets → Actions → New repository secret.
2. Name: `REDIS_URL` Value: the `rediss://...` string shown in Upstash.

Testing locally:

```bash
# set environment locally (replace <TOKEN> with your Upstash password)
export REDIS_URL='rediss://default:<TOKEN>@adapting-sunbeam-80687.upstash.io:6379/0'
redis-cli --tls -u redis://default:<TOKEN>@adapting-sunbeam-80687.upstash.io:6379 ping
# start Sidekiq
bundle exec sidekiq -C config/sidekiq.yml
```

I left the hostname above (`adapting-sunbeam-80687.upstash.io`) as an example since you provided it — replace `<TOKEN>` with the secret token from Upstash. Once `REDIS_URL` is configured, Sidekiq will connect automatically.
