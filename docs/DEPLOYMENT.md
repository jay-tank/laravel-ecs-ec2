# Deployment Guide — AWS ECS (EC2 launch type)

This guide walks through deploying the application to Amazon ECS on EC2
container instances, fronted by an Application Load Balancer, with images
stored in Amazon ECR and rollouts driven by GitLab CI.

> **Placeholders:** replace `<AWS_ACCOUNT_ID>` and `<AWS_REGION>` with your own
> values. Never commit real account IDs or credentials.

## Prerequisites

- AWS account with permissions for ECR, ECS, EC2, and ELB
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  configured (`aws configure`)
- A VPC with at least two public subnets (for the ALB)

---

## 1. Create the ECR repositories

Two images are published — the app and the Nginx proxy.

```bash
aws ecr create-repository --repository-name laravel-app  --region <AWS_REGION>
aws ecr create-repository --repository-name laravel-nginx --region <AWS_REGION>
```

## 2. Build and push images (manual, first time)

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region <AWS_REGION> \
  | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com

# Build
docker build -f Dockerfile       -t laravel-app:latest   .
docker build -f Dockerfile_Nginx -t laravel-nginx:latest .

# Tag & push
docker tag laravel-app:latest   <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/laravel-app:latest
docker tag laravel-nginx:latest <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/laravel-nginx:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/laravel-app:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/laravel-nginx:latest
```

> After the first manual push, the [CI/CD pipeline](#6-cicd-pipeline) handles
> subsequent builds and deploys automatically.

## 3. Create the ECS cluster

Create an **EC2 launch type** cluster (e.g. named `laravel`) with an Auto
Scaling group of container instances. Ensure the instances' security group
allows inbound `80`/`443` from the ALB and `3306` to your database.

## 4. Register the task definition

The task definition in [`../taskdef.json`](../taskdef.json) defines two
containers:

| Container | Image | Port mapping | Notes |
| :--- | :--- | :--- | :--- |
| `app` | `.../laravel-app:latest` | none | PHP-FPM; `essential` |
| `nginx` | `.../laravel-nginx:latest` | host `0` (dynamic) → container `80` | linked to `app`; `essential` |

Key settings:

- **Startup dependency ordering:** `nginx` waits for `app` to reach `START`.
- **Network links:** `nginx` links to `app` so `fastcgi_pass app:9000` resolves.
- **Logging:** both containers use the `awslogs` driver — create the log groups
  (`/ecs/laravel-app`) first, or let ECS create them.

Register it:

```bash
aws ecs register-task-definition \
  --cli-input-json file://taskdef.json \
  --region <AWS_REGION>
```

## 5. Create the ALB and ECS service

1. **Application Load Balancer** — internet-facing, across your public subnets,
   with a listener on port 80 (and 443 for TLS).
2. **Target group** — protocol HTTP, health-check path **`/health`**. Because
   the task uses dynamic host ports, the target type is *instance* managed by
   ECS.
3. **ECS service** — attach it to the ALB target group:

```bash
aws ecs create-service \
  --cluster laravel \
  --service-name laravel-deployment \
  --task-definition laravel-app \
  --desired-count 1 \
  --launch-type EC2 \
  --load-balancers "targetGroupArn=<TARGET_GROUP_ARN>,containerName=nginx,containerPort=80" \
  --region <AWS_REGION>
```

## 6. CI/CD pipeline

[`../.gitlab-ci.yml`](../.gitlab-ci.yml) runs two stages on pushes to `main`:

1. **build** — logs in to ECR, builds both images (tagged with the commit SHA
   and `latest`), and pushes them.
2. **deploy** — runs [`ecs-deploy`](https://github.com/fabfuel/ecs-deploy) to
   register a new task revision and roll the service with zero downtime.

### Required CI/CD variables

| Variable | Example |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | *(IAM key)* |
| `AWS_SECRET_ACCESS_KEY` | *(IAM secret)* |
| `AWS_DEFAULT_REGION` | `us-east-1` |
| `ECR_REGISTRY` | `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com` |
| `ECR_REPOSITORY_APP_IMAGE` | `${ECR_REGISTRY}/laravel-app` |
| `ECR_REPOSITORY_NGINX_IMAGE` | `${ECR_REGISTRY}/laravel-nginx` |
| `ECS_CLUSTER` | `laravel` |
| `ECS_SERVICE` | `laravel-deployment` |

Prefer an IAM role/OIDC over long-lived keys where your runner supports it.

## 7. Verify

```bash
curl http://<ALB_DNS_NAME>/health   # -> healthy
```

Then browse to the ALB DNS name for the application.

---

## Production hardening checklist

- [ ] Store secrets in **AWS Secrets Manager / SSM Parameter Store**, injected
      via the task definition's `secrets` block (not plain env vars).
- [ ] Terminate **TLS** at the ALB with an ACM certificate; redirect 80 → 443.
- [ ] Run the database on **Amazon RDS** and cache on **ElastiCache**.
- [ ] Enable **ECS service auto scaling** on CPU/memory or ALB request count.
- [ ] Set container **CPU/memory reservations** appropriate to your instances.
- [ ] Scope the deploy IAM policy to **least privilege**.
- [ ] Ship logs/metrics to **CloudWatch** (already wired via `awslogs`).
