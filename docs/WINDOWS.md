# Execução no Windows com Git Bash

O ambiente Windows suportado pelo lab é Windows 10/11 com Git Bash e
ferramentas de container e Kubernetes instaladas nativamente. Não é necessário
manter um checkout do repositório KIE Tools.

## Pré-requisitos

- Git for Windows, executando os comandos pelo Git Bash;
- Docker Desktop configurado para Linux containers;
- Docker Desktop iniciado, usando backend WSL 2 ou Hyper-V;
- `kind`, `kubectl`, `helm` e `skaffold` disponíveis no `PATH` do Git Bash;
- `curl` disponível no Git Bash e `tar.exe` disponível no Windows;
- JDK 21 para compilar ou executar diretamente a aplicação de `app/`.

Confirme as ferramentas antes do primeiro deploy:

```bash
docker info --format '{{.OSType}}'
kind version
kubectl version --client
helm version
skaffold version
curl --version
tar.exe --version
```

O primeiro comando deve imprimir `linux`. Kind e as imagens deste projeto não
funcionam com o Docker Desktop configurado para Windows containers.

O backend do Docker Desktop pode ser WSL 2 ou Hyper-V; os comandos do lab
continuam sendo executados no Git Bash do host.

## Checkout

O arquivo `.gitattributes` mantém scripts e arquivos usados em imagens com
terminadores LF. Se o repositório já havia sido clonado antes dessa regra,
normalize o checkout em uma árvore de trabalho limpa:

```bash
git add --renormalize .
git status
```

Revise o resultado antes de criar qualquer commit. Não execute esse comando
quando houver alterações locais que ainda não estejam protegidas.

## Runtime local

Na raiz do repositório:

```bash
skaffold run
bash scripts/test-deployment.sh
```

Também é possível executar somente a aplicação Java de forma nativa:

```bash
cd app
./mvnw.cmd clean test
./mvnw.cmd quarkus:dev
```

Ou usar Docker Compose:

```bash
cd app
docker compose up --build -d
docker compose ps
```

## Dev Deployment oficial

```bash
export DEV_DEPLOYMENT_UPLOAD_API_KEY='<chave-local-forte>'
bash scripts/deploy-official.sh
```

O script usa um arquivo temporário para transferir a chave ao `kubectl.exe`.
Isso evita passar `/dev/stdin`, que não é um caminho válido para executáveis
Windows.

## Editor web

```bash
bash scripts/start-web-editor.sh
```

O script imprime as URLs e o comando para obter o token. Mantenha o Git Bash
aberto enquanto os port-forwards estiverem em uso e encerre com `Ctrl+C`.

## Observações

- As portas 8080, 8081 e 9001 devem estar livres conforme o fluxo utilizado.
- Execute sempre os `.sh` com `bash scripts/<nome>.sh`.
