# Deploy local com Skaffold, Helm e Kind

## Ambiente validado

| Item | Valor |
| --- | --- |
| Cluster Kind | `kie-local` |
| Contexto Kubernetes | `kind-kie-local` |
| Namespace | `kie-dev` |
| Release Helm | `kie-runtime` |
| Deployment / Service | `kie-runtime` |
| Imagem | `kie-runtime-local:f8af5ec4989bf885f1d6521d3e8b0cf33a8a2ee48ebd7461a8350ca05a1e81aa` |
| Porta | `8080` |

O arquivo citado como `app/Containerfile` não existe. O projeto usa
`app/Dockerfile`, que é também o arquivo configurado em `skaffold.yaml`.
Nenhuma configuração do chart foi alterada nesta etapa.

## Build e deploy

O build validado foi:

```bash
skaffold build
```

Resultado: sucesso em 1,06 s, com todas as camadas Docker reutilizadas do
cache. A imagem tem 554 MB no Docker do host. O Skaffold/Kind confirmou que a
tag por conteúdo também está carregada no nó `kie-local-control-plane`.
Não houve push para registry.

O deploy único é:

```bash
skaffold run
```

O primeiro deploy desta etapa reutilizou a imagem local e concluiu em 16,99 s,
atualizando a release já existente para a revisão 6. Depois do teste completo
de limpeza, o deploy final concluiu em 16,31 s e reinstalou a release como
revisão 1.

Recursos finais:

- Deployment `kie-runtime`: `1/1` Ready e Available;
- Pod `kie-runtime`: `1/1 Running`, sem reinícios;
- Service `kie-runtime`: `ClusterIP`, porta 8080;
- release Helm `kie-runtime`: `deployed`;
- liveness e readiness em `/q/health`.

## Testes

O teste automatizado é:

```bash
bash scripts/test-deployment.sh
```

Ele exige o contexto `kind-kie-local`, confirma o namespace, encontra o
Service por label, inicia o port-forward, registra cleanup com `trap`, aguarda
a aplicação e valida:

- `GET /q/health`: HTTP 200, estado `UP`, processo `hello` versão `1.0`;
- `GET /q/openapi`: HTTP 200, documento YAML temporário com 4.871 bytes.

O OpenAPI contém as rotas `/hello`, `/hello/schema`, `/hello/{id}` e
`/hello/{id}/tasks`. Não existe modelo nem endpoint DMN neste projeto, então o
teste DMN não é aplicável.

O processo BPMN foi testado após o deploy final:

```bash
curl -i -X POST http://127.0.0.1:8080/hello \
  -H "Content-Type: application/json" \
  -d '{}'
```

Resposta real:

```http
HTTP/1.1 201 Created
Content-Type: application/json
Location: http://127.0.0.1:8080/hello/0345c9bc-f700-455b-8e32-136e9beae02b
content-length: 45

{"id":"0345c9bc-f700-455b-8e32-136e9beae02b"}
```

Todos os port-forwards foram encerrados após os testes. Nenhum `skaffold dev`
foi iniciado.

## Limpeza e restauração

O ciclo de limpeza validado foi:

```bash
skaffold delete
```

O comando desinstalou a release. Após aguardar a finalização do Pod, não
restaram Deployment, Service ou Pod com a label da release. O namespace
`kie-dev` e o cluster foram preservados.

Para restaurar o laboratório:

```bash
skaffold run
kubectl -n kie-dev rollout status deployment/kie-runtime
bash scripts/test-deployment.sh
```

## Verificação operacional

```bash
kubectl get deployments -n kie-dev
kubectl get pods -n kie-dev
kubectl get services -n kie-dev
helm list -n kie-dev
kubectl -n kie-dev logs deployment/kie-runtime
```

## Problemas observados

- `bash scripts/cluster-status.sh` falhou porque o diretório `scripts/` e o
  arquivo ainda não existiam. O contexto, clusters, nó e namespace foram
  verificados diretamente antes do deploy. O script ausente não foi inventado
  nesta etapa.
- Uma busca adicional por port-forward encontrou o próprio comando de busca,
  gerando falso positivo. A verificação foi repetida por nome exato de processo
  e confirmou que não havia `kubectl` em execução.
- Logo após `skaffold delete`, o Pod apareceu brevemente como `Error` enquanto
  era finalizado. Foi usado `kubectl wait --for=delete`; a remoção terminou
  normalmente.

Nenhum desses problemas exigiu mudança no chart ou na aplicação.
