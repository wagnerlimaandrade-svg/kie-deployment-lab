# Editor web integrado ao runtime do lab

O lab usa a imagem publicada do KIE Sandbox e recursos Kubernetes versionados neste repositório. O editor roda
em `http://localhost:9001`; uma ponte local expõe o Ingress do cluster
`kind-kie-local` em `http://localhost:8081`. Essa mesma origem atende:

- `/kube-apiserver`, usado pelo editor para criar e acompanhar recursos;
- `/<nome-do-deployment>`, usado para upload, health e Swagger do runtime.

Essa origem única é necessária porque o editor deriva a URL pública do runtime
a partir do host da conexão Kubernetes.

## Iniciar

Confirme primeiro os pré-requisitos Docker, Kind e kubectl. Então, na raiz do lab:

```bash
bash scripts/start-web-editor.sh
```

A imagem padrão do editor é
`docker.io/apache/incubator-kie-sandbox-webapp:main`. Para usar outra imagem,
defina `KIE_LAB_EDITOR_IMAGE`; não é necessário ter um checkout do KIE Tools.

O comando reaplica o manifesto Kubernetes local
`kind/kie-sandbox-dev-deployments-resources.yaml`, valida o
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
