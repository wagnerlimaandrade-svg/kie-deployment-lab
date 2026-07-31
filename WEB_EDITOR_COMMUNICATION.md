# Comunicação entre o Web Editor e o runtime

O Web Editor usa dois caminhos distintos: um para controlar os recursos do
Kubernetes e outro para enviar os arquivos do workspace ao container.

```text
                         CONTROLE DO KUBERNETES
Web Editor :9001
      |
      v
CORS Proxy :8080
      |  Bearer token
      v
localhost:8081/kube-apiserver
      |
      v
Ingress NGINX -> kube-apiserver-proxy -> Kubernetes API
                                      |
                                      +-- cria Deployment
                                      +-- cria Service
                                      +-- cria Ingress

                              UPLOAD DO ARQUIVO
Web Editor cria um ZIP
      |
      | POST /dev-deployment-.../upload?apiKey=...
      v
localhost:8081
      |
      v
Ingress NGINX -> Service -> Pod/container
                              |
                              +-- extrai o ZIP
                              +-- grava em /home/app/src/main/resources
                              +-- encerra o upload service
                              +-- inicia Maven/Quarkus
```

## 1. Criação do container

Ao confirmar um **Dev Deployment**, o editor usa o token Kubernetes para criar
três recursos no namespace `local-kie-sandbox-dev-deployments`:

- `Deployment`: cria o pod e o container;
- `Service`: disponibiliza a porta `8080` do container;
- `Ingress`: publica o caminho `/dev-deployment-<id>`.

Por exemplo:

```text
Deployment: dev-deployment-rde0a9g53
URL base:   http://localhost:8081/dev-deployment-rde0a9g53
```

As requisições de controle chegam à API Kubernetes por
`http://localhost:8081/kube-apiserver`. O caminho local completo é:

```text
Web Editor
  -> CORS Proxy
  -> port-forward da porta 8081
  -> Ingress NGINX
  -> Service kube-apiserver-proxy
  -> pod kube-apiserver-proxy
  -> Kubernetes API
```

O Bearer token configurado no editor autentica essas operações. No ambiente do
lab, ele pertence ao ServiceAccount `kie-sandbox-service-account`.

## 2. Envio do arquivo

O editor compacta o workspace em um ZIP e consulta periodicamente:

```text
GET /dev-deployment-<id>/upload-status
```

Quando o container responde `READY`, o editor envia:

```text
POST /dev-deployment-<id>/upload?apiKey=<chave-aleatoria>
Content-Type: multipart/form-data
```

Esse POST não usa o token Kubernetes. Cada Dev Deployment recebe uma chave de
upload aleatória própria.

O tráfego segue este caminho:

```text
Web Editor
  -> port-forward da porta 8081
  -> Ingress NGINX
  -> Service do Dev Deployment
  -> porta 8080 do container
```

## 3. Processamento dentro do container

Inicialmente, a imagem executa o `dev-deployment-upload-service`. Esse processo
recebe o ZIP e extrai seu conteúdo em:

```text
/home/app/src/main/resources
```

Depois da extração, o upload service encerra e o mesmo container inicia o
Maven/Quarkus. Os arquivos BPMN e DMN são compilados e seus endpoints passam a
ser publicados pelo runtime.

Os logs que comprovam essa transição incluem:

```text
Successfully extracted 'blob' to '/home/app/src/main/resources'
Listening on: http://0.0.0.0:8080
```

## 4. Acompanhamento do deployment

Depois do upload, o editor consulta o health do runtime:

```text
GET /dev-deployment-<id>/q/health
```

Quando o endpoint retorna o estado `UP`, o editor apresenta o deployment como
disponível. O Swagger UI fica em:

```text
http://localhost:8081/dev-deployment-<id>/q/swagger-ui/
```

Os recursos criados podem ser consultados com:

```bash
kubectl --context kind-kie-local \
  --namespace local-kie-sandbox-dev-deployments \
  get deployment,pod,service,ingress
```

Para listar os modelos dentro de um deployment:

```bash
kubectl --context kind-kie-local \
  --namespace local-kie-sandbox-dev-deployments \
  exec deployment/<nome-do-deployment> -- \
  find /home/app/src/main/resources -type f \
  \( -iname '*.bpmn' -o -iname '*.bpmn2' -o -iname '*.dmn' \)
```

Para verificar a extração e a inicialização do Quarkus:

```bash
kubectl --context kind-kie-local \
  --namespace local-kie-sandbox-dev-deployments \
  logs deployment/<nome-do-deployment> |
  grep -E 'Successfully extracted|Listening on'
```

## Persistência

O arquivo enviado fica na camada gravável do container. Esse fluxo não cria um
PersistentVolumeClaim (PVC). Se o pod for destruído e recriado, os arquivos
enviados podem ser perdidos, pois o novo pod começa novamente a partir da
imagem original.

Nesse caso, é necessário criar ou refazer o Dev Deployment pelo editor.
