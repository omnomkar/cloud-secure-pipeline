# secure-cloud-pipeline

A security-conscious cloud infrastructure portfolio project. The goal is to
show what "least privilege by default" looks like end-to-end — network,
compute, CI/CD, and secrets — while keeping monthly cost low enough to run
indefinitely as a personal project.

## Architecture (target state)

- **Compute**: single-node [k3s](https://k3s.io/) on one EC2 instance running
  a Python Flask app, instead of EKS — avoids the ~$73/mo EKS control plane
  fee while still using real Kubernetes primitives.
- **Network**: the k3s instance sits in a **private subnet**, single AZ,
  `us-east-1`. The only way out to the internet is a small NAT **instance**
  (~$5-10/mo on `t3.nano`) in a public subnet — not a managed NAT Gateway,
  which would cost more than the workload it's serving.
- **Access**: no SSH, no open inbound ports anywhere. All shell access goes
  through **AWS SSM Session Manager**, which only requires outbound HTTPS
  and an IAM role — no keys to lose, no bastion to patch.
- **CI/CD**: GitHub Actions authenticates to AWS via **OIDC** (no long-lived
  AWS credentials stored in GitHub). It builds and pushes images to
  **Amazon ECR**, then deploys by sending a command through **SSM
  send-command** — the Kubernetes API server is never exposed to the
  internet.
- **Deployment**: app manifests are packaged as **Helm charts**.
- **Secrets**: application secrets live in **AWS Secrets Manager**; the
  instance's IAM role is scoped to read only the specific secrets it needs.
- **Monitoring**: self-hosted **Prometheus + Grafana**, running as workloads
  on the same k3s node (no separate observability infrastructure to pay for).
- **Terraform state**: remote state in an **S3 bucket** (versioned,
  encrypted, public access blocked) with a **DynamoDB table** for locking.

## Repository layout

```
bootstrap/   Standalone Terraform that creates the S3 bucket + DynamoDB
             table used as the remote backend for everything else. Run
             once, with local state, before touching live/.
live/        The actual infrastructure (network, NAT instance, and later
             the k3s host, ECR, IAM for GitHub OIDC, etc.), using the S3
             backend bootstrap/ created.
app/         The Flask app that will eventually run on the k3s node.
Dockerfile   Builds app/ into a container image (build context is the
             repo root - see "The Flask app" section below).
```

`bootstrap` and `live` are deliberately separate Terraform root modules:
`live` depends on a backend that has to exist *before* `live` can run, so
it can't create its own backend without a chicken-and-egg problem.

## Phase status

- [x] **Phase 1 — Network + NAT instance + state backend**
  - `bootstrap/`: S3 state bucket + DynamoDB lock table
  - `live/`: VPC, public/private subnets, IGW, route tables, NAT instance
    (SSM-only access, IMDSv2 enforced, encrypted root volume, no SSH)
- [x] **Phase 2 — Flask app + container image** (this commit)
  - `app/`: minimal Flask app with `/`, `/health`, and `/config` routes
  - Root `Dockerfile`: non-root, gunicorn-served container image
- [ ] Phase 3 — k3s host in the private subnet, ECR repository, GitHub
      Actions OIDC role, Helm chart, deploy via SSM send-command
- [ ] Phase 4 — Secrets Manager integration, least-privilege IAM for app
- [ ] Phase 5 — Prometheus + Grafana on the cluster

## Setting up Phase 1 (do this yourself, by hand)

1. **Create the state backend** (uses local state, since it's creating the
   backend itself):
   ```
   cd bootstrap
   terraform init
   terraform apply -var="bucket_name=<your-globally-unique-bucket-name>"
   ```
   Note the `state_bucket_name` and `dynamodb_table_name` outputs.

2. **Point `live/` at that backend** — edit `live/providers.tf` and replace
   `REPLACE_WITH_YOUR_STATE_BUCKET_NAME` and
   `REPLACE_WITH_YOUR_LOCK_TABLE_NAME` with the values from step 1.

3. **Set your variables**:
   ```
   cd ../live
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars — at minimum set project_name
   ```

4. **Provision**:
   ```
   terraform init
   terraform plan
   terraform apply
   ```

5. To reach the NAT instance (or, later, the k3s host) for debugging, use
   SSM Session Manager — `aws ssm start-session --target <instance-id>` —
   never SSH.

## The Flask app (Phase 2)

`app/app.py` is a minimal Flask app with three routes:

- `GET /` — returns a small JSON status payload.
- `GET /health` — returns `{"status": "healthy"}`; this is what k3s will
  point liveness/readiness probes at in Phase 3.
- `GET /config` — returns a message read from the `APP_SECRET_MESSAGE`
  environment variable, falling back to a default if it isn't set. This is
  a stand-in for the real AWS Secrets Manager read that Phase 4 will add —
  same shape (an env var the app trusts), different source.

### Running it locally

Without Docker, using Flask's own dev server:

```
cd app
pip install -r requirements.txt
python app.py
```

The app listens on `http://localhost:5000`.

### Building the container image

The `Dockerfile` lives at the repo root (not in `app/`) so its build
context is the whole repo and `.dockerignore` can exclude things like
`bootstrap/`, `live/`, and `.terraform/` that have nothing to do with the
app image:

```
docker build -t secure-cloud-pipeline-app .
docker run -p 5000:5000 secure-cloud-pipeline-app
```

## Cost notes

- NAT instance (`t3.nano`) instead of NAT Gateway: NAT Gateway bills ~$0.045/hr
  plus per-GB data processing; a `t3.nano` is a flat ~$3-4/mo on-demand (less
  with a reserved/spot instance), at the cost of you owning patching and
  availability instead of AWS managing it.
- k3s on a single EC2 instance instead of EKS: no $73/mo control plane fee,
  at the cost of no managed HA control plane — acceptable for a portfolio
  project, not for production.

## A note on `.terraform.lock.hcl`

This file is intentionally committed (not gitignored): it pins exact
provider versions so `terraform init` resolves the same versions on every
machine and in CI, rather than potentially drifting to a newer provider
release between runs.
