# Playbook: KIE Dev Deployment oficial no Kind

Este fluxo foi validado ponta a ponta com build local, Helm, upload de modelos,
compilação Maven offline e os endpoints Quarkus. O caminho recomendado é:

```bash
export DEV_DEPLOYMENT_UPLOAD_API_KEY='<chave-local-forte>'
bash scripts/deploy-official.sh
```

O script cria o cluster Kind `kie-local` se necessário, seleciona o contexto
`kind-kie-local`, cria o namespace `kie-dev`, grava a chave em Secret,
empacota `models/`, executa o Skaffold, envia o ZIP e valida health e OpenAPI.
A chave não é impressa nem gravada no Git.

## Pré-requisitos

- Linux ou Windows 10/11 com Git Bash e Docker Desktop configurado para Linux
  containers;
- `kind`, `kubectl`, `skaffold` e `curl`;
- `zip` e `unzip` no Linux; no Windows, o script usa o `tar.exe` incluído no
  sistema;
- pelo menos 4 GiB disponíveis para o container do runtime;
- acesso à internet no primeiro build para Maven e imagens Docker.

Evite manter vários clusters Kind e builds pesados ativos simultaneamente.
Isso foi a principal condição associada aos travamentos observados. Confira
com `docker ps` e pare clusters que não estiver usando com `docker stop
<container-control-plane>`.

## Por que a imagem derivada existe

O perfil `official` parte de:

```text
docker.io/apache/incubator-kie-sandbox-dev-deployment-quarkus-blank-app:main
```

Após receber o ZIP, essa imagem inicia o Quarkus com Maven em modo offline.
Uma versão anterior de `:main` não continha `quarkus-devui` e o deploy falhava
somente depois do upload. O
`dev-deployment-image/Containerfile` executa `clean package
quarkus:go-offline` durante o build, usando:

- o `pom.xml` da própria imagem base;
- o Maven Wrapper e o `settings.xml` da própria imagem;
- o mesmo repositório local usado em runtime.

Assim não há uma versão do Quarkus duplicada no lab: quando a tag `:main`
muda, o cache continua alinhado ao POM que será executado. O Skaffold constrói
essa derivação, carrega-a diretamente no Kind e o Helm referencia a imagem por
digest. Não há push para registry.

O profile também aumenta o limite de memória de 768 MiB para 4 GiB. O runtime
completo ultrapassa com facilidade o limite anterior durante a geração dos
modelos.

## Execução manual

Se preferir observar cada etapa:

```bash
kind create cluster --name kie-local
kubectl config use-context kind-kie-local
kubectl create namespace kie-dev

export DEV_DEPLOYMENT_UPLOAD_API_KEY='<chave-local-forte>'
bash scripts/create-upload-secret.sh
bash scripts/package-models.sh
skaffold run -p official

kubectl -n kie-dev port-forward service/kie-runtime 8080:8080
```

Em outro terminal:

```bash
export DEV_DEPLOYMENT_UPLOAD_API_KEY='<a-mesma-chave>'
bash scripts/upload-models.sh
```

Durante a transição do servidor de upload para o Quarkus, a porta 8080 fecha
temporariamente e o `port-forward` pode terminar. Isso é esperado. Aguarde a
mensagem `Listening on: http://0.0.0.0:8080`:

```bash
kubectl -n kie-dev logs -f deployment/kie-runtime
```

Então abra novamente:

```bash
kubectl -n kie-dev port-forward service/kie-runtime 8080:8080
```

Valide:

```bash
curl --fail http://127.0.0.1:8080/q/health
curl --fail http://127.0.0.1:8080/q/openapi
```

Ou use o smoke test, que gerencia seu próprio port-forward:

```bash
bash scripts/test-deployment.sh
```

## Fluxo local sem upload

O perfil padrão continua independente:

```bash
skaffold run
bash scripts/test-deployment.sh
```

Ele constrói `app/Dockerfile` e é apropriado para o modelo fixo incluído em
`app/`. O perfil `official` é o fluxo equivalente ao Web Editor: inicia o
upload service e só depois compila os arquivos de `models/`.

## Diagnóstico

```bash
skaffold diagnose --yaml-only -p official
helm lint deploy/helm/kie-runtime \
  -f deploy/helm/kie-runtime/values-official.yaml
kubectl -n kie-dev get pods
kubectl -n kie-dev logs deployment/kie-runtime --tail=200
kubectl -n kie-dev describe pod -l app.kubernetes.io/instance=kie-runtime
```

Sinais de sucesso:

- upload retorna HTTP 200;
- log termina com `Listening on: http://0.0.0.0:8080`;
- `/q/health` retorna `"status": "UP"`;
- o processo dos modelos aparece no health;
- pod permanece sem reinícios.

## Limpeza

Remova somente a release:

```bash
skaffold delete -p official
```

O Secret permanece no namespace. Remova-o apenas se a chave não for mais
necessária:

```bash
kubectl -n kie-dev delete secret kie-dev-deployment-upload
```

Para apagar o cluster inteiro:

```bash
kind delete cluster --name kie-local
```

## Validação registrada

Em 27 de julho de 2026, o fluxo final produziu:

- build Maven `clean package quarkus:go-offline`: sucesso;
- build e carga da imagem pelo Skaffold: sucesso;
- upgrade Helm e estabilização do deployment: sucesso;
- upload do ZIP: HTTP 200;
- Quarkus `3.27.4.1`: iniciado;
- `/q/health`: `UP`, com processo `upload_test` versão `1.0`;
- `/q/openapi`: HTTP 200;
- pod: Ready, zero reinícios;
- recursos: request 512 MiB e limite 4 GiB.
