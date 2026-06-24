# README

<img width="560" height="671" alt="image" src="https://github.com/user-attachments/assets/78ef84a4-d235-4e12-a261-dd796878aaa7" />

## Lunar phase email (per-phase, not daily)

The newsletter is **not** sent every day. It runs once per day on AWS and only
sends an email on the **actual day of a principal moon phase** — Lua Nova,
Primeiro Quarto, Lua Cheia, Último Quarto — or when there's a **special moon**
(super lua, lua azul, etc.). On any other day the job detects no phase and
exits without sending. Each email is in Brazilian Portuguese and includes the
astronomical data plus per-phase **tarot reading guidance** (inspired by
[Tarot with Gord](http://tarotwithgord.com/best-moon-phase-for-tarot-reading/)).

How "the day of each phase" is detected: the job makes one call to the moon API
and checks the current `phase.name`. The four principal phase names only appear
on/around their exact instant, so `phase.name ∈ {new_moon, first_quarter,
full_moon, last_quarter}` (or a non-empty `special_moon.labels`) marks a send
day. Delivery date and the schedule use `DELIVERY_TIME_ZONE` (default
`Europe/Stockholm`, which is the IANA zone covering Malmö).

### Preview the email locally

```bash
bin/rails server
```

Then open the built-in mailer preview (one variant per principal phase):

```text
/rails/mailers/user_data_mailer/lunar_phase_email_nova
/rails/mailers/user_data_mailer/lunar_phase_email_quarto_crescente
/rails/mailers/user_data_mailer/lunar_phase_email_cheia
/rails/mailers/user_data_mailer/lunar_phase_email_quarto_minguante
```

Preview data lives in `test/mailers/previews/user_data_mailer_preview.rb`.

### Run the job manually

    bin/rails cron:lunar_phase_email

Or with rake/bundle in any environment:

    bundle exec rake cron:lunar_phase_email RAILS_ENV=production

Notes:

- Email delivery uses `MAIL_DELIVERY_METHOD` (`ses` in production via the ECS
  task IAM role; `smtp` as a fallback using the `SMTP_*` vars).
- The job dedupes per user **per phase + date** (Redis), so overlapping runs
  won't send two copies.

### Production scheduling (AWS)

Scheduling and sending run on AWS: **EventBridge Scheduler → ECS Fargate →
SES**. The Fargate task runs `rake cron:lunar_phase_email` daily; the job
decides whether today is a phase day. See [`infra/`](infra/README.md) for the
Terraform and deploy steps (ECR, ECS, IAM, Secrets Manager, schedule).

The old GitHub Actions **scheduled** run has been removed; the workflow at
`.github/workflows/daily_lunar_email.yml` is now manual-only
(`workflow_dispatch`) for ad-hoc testing.

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

- This repo includes `config/sidekiq_scheduler.yml` and `config/sidekiq.yml` — when Sidekiq starts the initializer will load the cron schedule (requires `sidekiq-cron`). Configure the cron there (they currently contain `lunar_phase_email`). Note: in production the AWS schedule in `infra/` is the source of truth; the job self-gates so a daily trigger only sends on a phase day.

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
