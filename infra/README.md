# Infra — Boletim lunar por fase (AWS)

Roda o boletim lunar na AWS, **uma vez por dia**, e só envia e-mail nos dias de
**fase principal** (Lua Nova, Primeiro Quarto, Lua Cheia, Último Quarto) ou de
**lua especial**. Fluxo:

```
EventBridge Scheduler (cron diário, no fuso de entrega)
  -> ecs:RunTask (Fargate, imagem do Dockerfile do repo)
     -> ./bin/rails cron:lunar_phase_email
        -> envia via AWS SES (só em dia de fase)
```

A app continua usando o Postgres (Neon) e o Redis existentes — a task só precisa
de saída de rede para alcançá-los.

## Pré-requisitos (uma vez, fora do Terraform)

1. **SES**: verifique o domínio/e-mail remetente e **saia do sandbox** (Production
   access) para enviar a destinatários arbitrários. Anote o `MAIL_FROM`.
2. **Secrets Manager**: crie os segredos referenciados em `secret_names`:

   ```bash
   aws secretsmanager create-secret --name artemis/rails_master_key    --secret-string "$(cat ../config/master.key)"
   aws secretsmanager create-secret --name artemis/database_url         --secret-string "postgres://...neon..."
   aws secretsmanager create-secret --name artemis/astro_api_key        --secret-string "..."
   aws secretsmanager create-secret --name artemis/daily_lunar_api_url  --secret-string "https://api.freeastroapi.com/api/v1/moon/phase"
   aws secretsmanager create-secret --name artemis/redis_url            --secret-string "rediss://..."
   ```

3. **Rede**: tenha um `vpc_id` e `subnet_ids` com saída à internet (subnet pública
   + `assign_public_ip = true`, ou subnet privada + NAT Gateway).

## Deploy

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # preencha os valores
terraform init
terraform apply                                 # cria ECR, ECS, IAM, schedule...
```

Depois faça **build & push** da imagem para o ECR criado:

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
REGION=$(terraform output -raw ... 2>/dev/null || echo us-east-1)

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URL"
docker build -t "$ECR_URL:latest" ..
docker push "$ECR_URL:latest"
```

(Se a imagem for enviada depois do `apply`, basta o push — a task definition já
aponta para a tag `latest`.)

## Teste manual (sem esperar o cron)

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
TASKDEF=$(terraform output -raw task_definition_arn)

aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$TASKDEF" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-aaaa],securityGroups=[sg-xxxx],assignPublicIp=ENABLED}"
```

Acompanhe os logs no grupo `terraform output -raw log_group` (CloudWatch). Em um
dia sem fase principal, o log mostra `no principal phase or special moon ...` e
nada é enviado.

## Variáveis principais

| Variável               | Descrição                                                        |
|------------------------|------------------------------------------------------------------|
| `delivery_time_zone`   | Fuso IANA (ex.: `Europe/Stockholm`, que cobre Malmö) — data de referência e cron |
| `schedule_expression`  | Cron do scheduler (avaliado no fuso acima)                       |
| `mail_from`            | Remetente verificado no SES                                      |
| `secret_names`         | Mapa env var => segredo no Secrets Manager                       |

> O agendamento legado do GitHub Actions foi desativado — esta infra é a única
> que dispara o boletim. Veja a raiz do repo (`config/environments/production.rb`)
> para o `MAIL_DELIVERY_METHOD` (padrão `ses`).

## CI/CD — deploy automático pelo GitHub Actions

O workflow `.github/workflows/deploy.yml` dispara **apenas** em push/merge na
branch `main` e **somente se o `CI` passar** para aquele commit; faz **build +
push** da imagem para o ECR. Não há disparo manual — `main` é o único caminho
para um deploy. Como a task definition aponta para a tag `:latest`, o próximo
`RunTask` agendado já usa a nova imagem — não é preciso atualizar a task definition.

Configure em **Settings → Secrets and variables → Actions**:

- **Secrets**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (de um usuário IAM com
  permissão de push no ECR — `ecr:GetAuthorizationToken` + as ações
  `ecr:*Upload*`/`ecr:BatchCheckLayerAvailability`/`ecr:PutImage` no repositório).
- **Variables** (opcionais; têm default): `AWS_REGION` (default `us-east-1`) e
  `ECR_REPOSITORY` (default `artemis`).
