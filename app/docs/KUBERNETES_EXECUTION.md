# Execução local no Kubernetes

Este documento descreve o deploy da aplicação BPMN existente no cluster local. O pacote contém somente `hello.bpmn`; nenhum modelo DMN, processo adicional, banco de dados ou broker é implantado.

## Ambiente validado

| Item | Valor |
| --- | --- |
| Ferramenta de cluster | Kind 0.32.0 |
| Cluster | `kie-local` |
| Contexto Kubernetes | `kind-kie-local` |
| Kubernetes | 1.36.1 |
| Namespace | `kie-dev` |
| Deployment e Service | `kie-runtime` |
| Imagem | `kie-runtime-local:dev` |
| Porta HTTP | 8080 |

O cluster já existia e estava `Ready`; ele não foi criado, reiniciado ou removido durante esta etapa. Por isso, nenhum comando de criação ou inicialização de cluster foi necessário. Para verificar o ambiente:

```bash
kind get clusters
kubectl config current-context
kubectl get nodes
```

## Pré-requisitos

- Docker Engine funcional;
- Kind;
- `kubectl` com Kustomize;
- JDK 21 para o build Maven no host;
- contexto atual `kind-kie-local`.

Antes de aplicar recursos, confirme explicitamente o contexto:

```bash
kubectl config current-context
```

Este procedimento não troca o contexto automaticamente.

## Construir e testar a aplicação

A partir do diretório `app/`:

```bash
./mvnw clean test
./mvnw clean package
```

O projeto produz um Quarkus fast-jar em `target/quarkus-app/`.

## Construir e carregar a imagem

Ainda em `app/`:

```bash
docker build -t kie-runtime-local:dev .
kind load docker-image kie-runtime-local:dev --name kie-local
```

O carregamento é direto no node do Kind; nenhum registry externo é usado. O Deployment utiliza `imagePullPolicy: Never` para impedir tentativa de download externo.

## Aplicar os manifestos

A partir da raiz do repositório:

```bash
kubectl apply -k app/k8s
kubectl -n kie-dev rollout status deployment/kie-runtime
```

Os manifestos criam ou reconciliam apenas o namespace `kie-dev`, um Deployment com uma réplica e um Service `ClusterIP`.

## Verificar os recursos

```bash
kubectl -n kie-dev get all
kubectl -n kie-dev get pods -o wide
kubectl -n kie-dev describe deployment kie-runtime
kubectl -n kie-dev logs deployment/kie-runtime
```

As probes usam endpoints confirmados antes do deploy:

- readiness: `/q/health/ready`;
- liveness: `/q/health/live`.

## Acessar por port-forward

```bash
kubectl -n kie-dev port-forward service/kie-runtime 8080:8080
```

Esse comando permanece em primeiro plano. Para encerrá-lo, pressione `Ctrl+C`.

Em outro terminal, inicie o processo:

```bash
curl -i -X POST http://localhost:8080/hello \
  -H "Content-Type: application/json" \
  -d '{}'
```

O processo não declara parâmetros. Esta foi a resposta real obtida durante a validação; o UUID varia a cada execução:

```http
HTTP/1.1 201 Created
Content-Type: application/json
Location: http://localhost:8080/hello/7277e5bf-1cda-49b3-a10f-cd77ebec3e47
content-length: 45

{"id":"7277e5bf-1cda-49b3-a10f-cd77ebec3e47"}
```

## Logs

```bash
kubectl -n kie-dev logs deployment/kie-runtime
kubectl -n kie-dev logs -f deployment/kie-runtime
```

## Remover somente a aplicação

A partir da raiz do repositório:

```bash
kubectl delete -k app/k8s
```

Esse comando também remove o namespace declarado pelo Kustomize. Use-o somente quando desejar remover todos os recursos dedicados a esta aplicação. Ele não destrói o cluster Kind.

## Resultado da validação

Validação executada em 2026-07-27:

- `./mvnw clean test`: sucesso, 2 testes, 0 falhas e 0 erros;
- `./mvnw clean package`: sucesso, 2 testes, 0 falhas e 0 erros;
- `docker build -t kie-runtime-local:dev .`: sucesso;
- `kind load docker-image kie-runtime-local:dev --name kie-local`: imagem carregada no node `kie-local-control-plane`;
- `kubectl apply -k app/k8s`: namespace configurado, Service e Deployment criados;
- rollout: `deployment "kie-runtime" successfully rolled out`;
- Pod: `1/1 Running`, 0 reinícios;
- Deployment: `1/1` disponível;
- Service: `ClusterIP`, porta `8080/TCP`;
- consumo observado após o startup: aproximadamente 93.57 MB de memória e 0.09% de CPU;
- readiness via port-forward: HTTP 200, estado `UP`;
- `POST /hello`: HTTP 201, com o UUID mostrado no exemplo acima.

Logs relevantes:

```text
kie-runtime 0.0.0 on JVM (powered by Quarkus 3.27.2) started
Listening on: http://0.0.0.0:8080
Hello from the KIE local runtime
```

O container Docker Compose da mesma aplicação foi encerrado com `docker compose down` antes do port-forward porque já ocupava `localhost:8080`. A imagem local não foi removida. O port-forward foi encerrado com `Ctrl+C` depois dos testes; os recursos Kubernetes permaneceram em execução.

## Limitações conhecidas

- Há uma única réplica e não existe persistência de instâncias.
- O acesso local depende de um processo `kubectl port-forward` ativo.
- A imagem precisa ser recarregada com `kind load docker-image` após cada rebuild.
- A tag `dev` é local e não é publicada em registry.
- O Deployment usa recursos conservadores para desenvolvimento: request de 100m CPU/256Mi e limite de 500m CPU/768Mi.
