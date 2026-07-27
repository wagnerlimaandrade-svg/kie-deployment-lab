# Integração local com Skaffold

## Ambiente validado

| Item | Valor |
| --- | --- |
| Skaffold anterior | `v0.25.0`, `/snap/bin/skaffold` |
| Skaffold atual | `v2.24.0`, `/usr/local/bin/skaffold` |
| Arquitetura | Linux `x86_64` / Debian `amd64` |
| Schema | `skaffold/v4beta14` |
| Kubernetes | Kind, cluster `kie-local`, contexto `kind-kie-local` |
| Namespace | `kie-dev` |
| Artifact | `kie-runtime-local` |
| Chart / release | `deploy/helm/kie-runtime` / `kie-runtime` |

O pacote Snap limitava o projeto ao schema legado `v1beta7` e não conseguia acessar o Docker. A instalação Snap foi substituída, com autorização explícita, pelo binário oficial fixado em `v2.24.0`. Docker, socket, grupos, serviço, cluster e contexto não foram reconfigurados.

Os comandos de instalação executados foram:

```bash
sudo snap remove skaffold
curl -Lo /tmp/skaffold \
  https://storage.googleapis.com/skaffold/releases/v2.24.0/skaffold-linux-amd64
chmod +x /tmp/skaffold
sudo install /tmp/skaffold /usr/local/bin/skaffold
hash -r
```

## Configuração

O build em `skaffold.yaml` usa contexto `app`, `app/Dockerfile`, Docker local, `push: false` e `tagPolicy.sha256`.

O chart representa a imagem nas propriedades `image.repository`, `image.tag` e `image.pullPolicy`. A integração moderna usa `setValueTemplates`; o nome do artifact com hífens é sanitizado para `kie_runtime_local` nas variáveis:

```yaml
setValueTemplates:
  image.repository: "{{.IMAGE_REPO_kie_runtime_local}}"
  image.tag: "{{.IMAGE_TAG_kie_runtime_local}}@{{.IMAGE_DIGEST_kie_runtime_local}}"
setValues:
  image.pullPolicy: IfNotPresent
```

O Helm cria `kie-dev` caso necessário, instala a release `kie-runtime` e aguarda o Deployment. O port-forward declarativo mapeia o Service `kie-runtime`, porta 8080, somente para `127.0.0.1:8080`.

## Comandos validados

Validação e renderização:

```bash
skaffold diagnose
skaffold schema list
helm lint deploy/helm/kie-runtime
skaffold render
```

Build único, sem push:

```bash
skaffold build
```

Deploy único:

```bash
skaffold run
```

Deploy com o port-forward declarativo ativo:

```bash
skaffold run --port-forward
```

Desenvolvimento contínuo:

```bash
skaffold dev
```

Na validação desta etapa foi usado `skaffold dev --cleanup=false`, para preservar a release quando o processo foi interrompido com `Ctrl+C`. Sem essa opção, o modo dev normalmente limpa os recursos que gerencia ao encerrar.

O Skaffold detectou o contexto Kind e carregou cada imagem diretamente nos nós. O mesmo procedimento manual, quando necessário, é:

```bash
kind load docker-image <imagem-com-tag> --name kie-local
```

Não há push para registry externo.

## Teste funcional e logs

Com `skaffold run --port-forward` ou `skaffold dev` em execução:

```bash
curl -i -X POST http://127.0.0.1:8080/hello \
  -H "Content-Type: application/json" \
  -d '{}'
```

Resposta real obtida após a reversão da alteração temporária:

```http
HTTP/1.1 201 Created
Content-Type: application/json
Location: http://127.0.0.1:8080/hello/bf684ed1-96be-4c2e-8d8a-a7d54c2eac90
content-length: 45

{"id":"bf684ed1-96be-4c2e-8d8a-a7d54c2eac90"}
```

Para consultar logs:

```bash
kubectl -n kie-dev logs deployment/kie-runtime
```

O log correspondente contém `Hello from the KIE local runtime`.

## Ciclo de rebuild validado

Durante `skaffold dev --cleanup=false`, foi acrescentado temporariamente um comentário em `application.properties`, sem mudar a regra de negócio. O Skaffold detectou a alteração, construiu a imagem `d21320dd...`, carregou-a no Kind, atualizou a release para a revisão 4 e o endpoint respondeu HTTP 201.

O comentário foi removido ainda durante o ciclo. O Skaffold detectou a reversão, construiu `f8af5ec4...`, atualizou a release para a revisão 5 e `POST /hello` voltou a responder HTTP 201. A aplicação terminou em Pod `Running`, e a alteração temporária não permaneceu no projeto.

## Limitações conhecidas

- A primeira camada Maven de um build não cacheado baixa muitas dependências e pode demorar; builds sem mudanças usam o cache Docker.
- O build registra avisos já existentes sobre duas chaves de log não reconhecidas, split package e índice Jandex. Eles não impedem o pacote, o startup, as probes ou o endpoint BPMN.
- O endpoint cria IDs diferentes em cada chamada; exemplos de resposta são registros de uma execução real, não valores estáveis.
- `localhost:8080` precisa estar livre para o port-forward declarativo.
