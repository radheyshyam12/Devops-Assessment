# DevOps Assessment: Terraform + Database Reliability

AWS infrastructure designed with Terraform (plan-only, nothing is deployed) plus a local PostgreSQL
database with migrations, seed data, an optimized query, and backup/restore scripts.

```
Internet ──► ALB (public subnets) ──► ECS Fargate (private subnets) ──► RDS PostgreSQL (private subnets)
              alb-sg :80                ecs-sg :80 from alb-sg            rds-sg :5432 from ecs-sg only
```

## Repository layout

```
.
├── docker-compose.yml            # local PostgreSQL 16
├── db/
│   ├── migrations/               # 001 tables, 002 indexes
│   ├── seed/003_seed.sql         # 2,000 bookings + ~3,000 events
│   └── queries/optimized_query.sql
├── scripts/
│   ├── backup.sh                 # timestamped pg_dump
│   ├── restore.sh                # restore into a fresh DB + verify
│   └── tf-review.sh              # fmt/init/validate/plan without AWS credentials
├── infra/
│   ├── modules/{network,ecs,rds}
│   └── envs/{dev,prod}           # variables, tfvars, backend, sizing per environment
└── .github/workflows/terraform.yml
```

## Prerequisites

Docker + Docker Compose v2 (database tasks), Terraform >= 1.6 (infra tasks). No AWS account is needed.

---

## Part 1 & 2: Terraform

### What is built

| Module | Resources |
|---|---|
| `network` | VPC, 2 public + 2 private subnets (2 AZs), IGW, NAT gateway(s), route tables, **ALB / ECS / RDS security groups** |
| `ecs` | ECS cluster (Container Insights), Fargate task definition (nginx placeholder), service, ALB + target group + listener, CloudWatch log group, execution + task IAM roles |
| `rds` | Subnet group, PostgreSQL 16 instance (encrypted, gp3, private, managed master password) |

**RDS is private and only reachable from ECS:**
- `publicly_accessible = false` and the DB lives in private subnets (no route to the IGW).
- `rds-sg` has a single ingress rule: TCP 5432 from `ecs-sg` (a security group reference, not a CIDR) and no egress rules.
- Security group chain: Internet → `alb-sg` (80) → `ecs-sg` (app port from `alb-sg`) → `rds-sg` (5432 from `ecs-sg`).

**Credentials:** `manage_master_user_password = true` makes RDS create the password in Secrets Manager. The
ECS execution role can read that one secret and it is injected into the container as `DB_PASSWORD`. No password appears in code, tfvars or state.

### Environments

Each of `infra/envs/dev` and `infra/envs/prod` has its own `variables.tf`, `terraform.tfvars`, `backend.tf`
(separate S3 bucket, state key and DynamoDB lock table), and sizing.

| Setting | dev | prod |
|---|---|---|
| RDS instance | `db.t4g.micro`, 20 GB (max 50) | `db.m6g.large`, 100 GB (max 500) |
| RDS Multi-AZ | false | true |
| Backup retention | 3 days | 35 days |
| Deletion protection (RDS + ALB) | **false** | **true** |
| Final snapshot on destroy | skipped | taken |
| NAT gateways | 1 shared | 1 per AZ |
| Fargate task / count | 0.25 vCPU, 512 MiB x 1 | 1 vCPU, 2 GiB x 3 |
| Log retention | 7 days | 90 days |

### Review commands

Simplest (no AWS account, runs fmt, init, validate, plan):

```bash
./scripts/tf-review.sh dev
./scripts/tf-review.sh prod
```

Or manually. The real `backend.tf` uses S3, so to run without AWS access, drop in a local-backend
override first (it is git-ignored):

```bash
cd infra && terraform fmt -check -recursive
cd envs/dev
cat > backend_override.tf <<'TF'
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
TF
terraform init
terraform validate
terraform plan -refresh=false      # terraform.tfvars is picked up automatically
rm backend_override.tf
```

`offline_plan = true` (set in each `terraform.tfvars`) makes the AWS provider skip credential and account lookups, and
the code uses no data sources that call AWS (AZs are passed in as variables), so `plan -refresh=false` works fully offline.
For a real deployment, set `offline_plan = false`, use real credentials, create the state bucket/lock table, and run `terraform init` with the S3 backend.

---

## Part 3: GitHub Actions (optional part, included)

`.github/workflows/terraform.yml` runs on pull requests touching `infra/**`:

1. `terraform fmt -check -recursive`
2. For `dev` and `prod` (matrix): `init`, `validate`, `plan -refresh=false`
3. The plan is shared **three ways**: a PR comment (one per env, updated on every push), a workflow artifact (`plan.txt` + `tfplan`), and the job summary.

It uses the same local-backend, offline mode as above, so it needs no AWS secrets. To plan against real state, replace that step with OIDC credentials (`aws-actions/configure-aws-credentials`) and set `offline_plan=false`.

---

## Part 4 & 5: Local database, seed data, indexing

```bash
docker compose up -d --wait        # starts Postgres and runs migrations + seed on first boot
```

Migrations and seed run automatically from `/docker-entrypoint-initdb.d` (only on an empty volume).
To reset everything: `docker compose down -v && docker compose up -d --wait`.
Connection defaults: user `hotel`, password `hotel_pw`, db `hotel_bookings`, port 5432 (override via `.env`, see `.env.example`).

Check the data:

```bash
docker compose exec db psql -U hotel -d hotel_bookings -c "
  SELECT count(*) AS bookings, count(DISTINCT city) AS cities,
         count(DISTINCT org_id) AS orgs, count(DISTINCT status) AS statuses
  FROM hotel_bookings;"
docker compose exec db psql -U hotel -d hotel_bookings -c "SELECT count(*) AS events FROM booking_events;"
```

Expected: 2,000 bookings, 6 cities, 5 orgs, 4 statuses, ~3,000 events (pending bookings have only a
`booking_created` event, so only some bookings have later lifecycle events).

### The index

```sql
CREATE INDEX idx_hotel_bookings_city_created_at_cov
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

Why this shape:

- **`city` first**: it is an equality predicate, so it pins one contiguous slice of the B-tree.
- **`created_at` second**: the 30-day filter is a range on the same slice, so Postgres reads only the matching leaf pages in order.
- **`INCLUDE (org_id, status, amount)`**: the query only needs these extra columns for `GROUP BY` and `COUNT`/`SUM`. Storing them as non-key payload allows an **Index Only Scan** with no table lookups, without making the key wider (they are not searchable keys).
- Putting `created_at` before `city` would be wrong: a range column first stops the index from narrowing by city.
- A second index on `booking_events (booking_id, created_at)` supports event lookups per booking and the FK cascade.

Verify the plan (the seed ends with `VACUUM ANALYZE`, which is what lets Postgres choose an index-only scan):

```bash
docker compose exec -T db psql -U hotel -d hotel_bookings < db/queries/optimized_query.sql
# expect: "Index Only Scan using idx_hotel_bookings_city_created_at_cov"

# compare with no index:
docker compose exec db psql -U hotel -d hotel_bookings -c "DROP INDEX idx_hotel_bookings_city_created_at_cov;"
docker compose exec -T db psql -U hotel -d hotel_bookings < db/queries/optimized_query.sql   # expect Seq Scan
# put it back:
docker compose exec db psql -U hotel -d hotel_bookings -c "CREATE INDEX idx_hotel_bookings_city_created_at_cov ON hotel_bookings (city, created_at) INCLUDE (org_id, status, amount);"
```

---

## Part 6: Backup and restore

```bash
./scripts/backup.sh      # -> backups/hotel_bookings_<UTC timestamp>.dump (+ .sha256)
./scripts/restore.sh     # restores the latest dump into a NEW database "hotel_restore"
```

- `backup.sh`: runs `pg_dump -Fc` (compressed custom format) inside the container, writes to a temp file then renames it (no half-written backups), checks the archive with `pg_restore --list`, and records a SHA-256.
- `restore.sh [file] [target_db]`: drops/recreates `hotel_restore` (it refuses to overwrite the source DB), runs `pg_restore --exit-on-error`, then verifies.

### How to verify the restore worked

`restore.sh` verifies automatically and ends with `RESTORE VERIFIED`. It checks that:
1. `hotel_bookings` row count and `SUM(amount)` match the source DB,
2. `booking_events` row count matches,
3. both custom indexes exist in the restored database.

Manual double-check:

```bash
docker compose exec db psql -U hotel -d hotel_restore -c "SELECT count(*), sum(amount) FROM hotel_bookings;"
docker compose exec db psql -U hotel -d hotel_restore -c "\di"          # indexes were restored
docker compose exec -T db psql -U hotel -d hotel_restore < db/queries/optimized_query.sql
```

A complete restore drill from scratch:

```bash
./scripts/backup.sh
docker compose down -v && docker compose up -d --wait   # simulate losing the data
# (the seed recreates data; to prove the dump alone is enough, restore into another DB:)
./scripts/restore.sh backups/<file>.dump hotel_restore_2
```

---

## Design notes and assumptions

- PostgreSQL was chosen for both RDS and local so schemas and tooling match (`UUID`, `JSONB`, `BIGSERIAL`).
- An FK (`booking_events.booking_id -> hotel_bookings.id`) and CHECK constraints (`amount >= 0`, `checkout > checkin`) were added to the suggested schema for integrity.
- The ALB listens on HTTP only, to avoid requiring a domain/ACM certificate. Production next steps: ACM cert + HTTPS listener with HTTP→HTTPS redirect, WAF, ECS autoscaling, access logs, VPC endpoints for ECR/Logs/Secrets Manager to cut NAT traffic.
- Remote-state bucket names in `backend.tf` are placeholders; create the bucket and lock table before a real `init`.
