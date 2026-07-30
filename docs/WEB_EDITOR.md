# Editor web integrado ao runtime do lab

O lab usa o KIE Sandbox do checkout irmão `upstream-kie-tools`. O editor roda
em `http://localhost:9001`; uma ponte local expõe o Ingress do cluster
`kind-kie-local` em `http://localhost:8081`. Essa mesma origem atende:

- `/kube-apiserver`, usado pelo editor para criar e acompanhar recursos;
- `/<nome-do-deployment>`, usado para upload, health e Swagger do runtime.

Essa origem única é necessária porque o editor deriva a URL pública do runtime
a partir do host da conexão Kubernetes.

## Iniciar

Confirme primeiro os pré-requisitos do upstream, principalmente Node 24, pnpm
10.34.4, Maven 3.9.11 e Java 17. Então, na raiz do lab:

```bash
scripts/start-web-editor.sh
```

Se o checkout upstream estiver em outro caminho:

```bash
KIE_TOOLS_REPO=/caminho/para/upstream-kie-tools \
  scripts/start-web-editor.sh
```

O comando reaplica o manifesto Kubernetes versionado no upstream, valida o
proxy da API, inicia o port-forward do Ingress e inicia o editor caso ele ainda
não esteja ativo. Se `http://localhost:9001/env.json` já responder, o processo
existente é reutilizado.

Quando `kie-dev-deployment-offline:latest` existe localmente, o script também a
associa à tag padrão usada pelo editor e a carrega no Kind. Isso garante que
novos Dev Deployments tenham o cache completo do `quarkus:dev -o`; uma tag
upstream antiga pode não conter `io.quarkus:quarkus-devui`. A imagem é criada
pelo fluxo `scripts/deploy-official.sh`. Use `KIE_LAB_OFFLINE_IMAGE` para
selecionar outra imagem derivada já validada.

## Conectar no editor

Abra `http://localhost:9001` e crie uma conexão Kubernetes com:

- Host: `http://localhost:8081/kube-apiserver`;
- Namespace: `local-kie-sandbox-dev-deployments`;
- Insecurely disable TLS certificate validation: desmarcado;
- Token: execute o comando mostrado por `scripts/start-web-editor.sh`.

Depois abra um BPMN ou DMN, escolha **Dev Deployments**, selecione **Quarkus
Blank App** e confirme. O editor envia o projeto ao upload service; quando a
compilação termina, o link do deployment abre o Swagger UI do runtime pela
mesma porta `8081`.

## Validação rápida

Com o script em execução:

```bash
curl --fail http://localhost:9001/env.json
curl --fail http://localhost:8081/kube-apiserver/version
kubectl --context kind-kie-local \
  --namespace local-kie-sandbox-dev-deployments \
  get deployment,pod,service,ingress
```

Interrompa o script com `Ctrl+C`; ele encerra apenas os processos locais que
iniciou e não remove deployments do cluster.
