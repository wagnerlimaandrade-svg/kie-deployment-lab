# Helm Chart do KIE Runtime

## Objetivo

O chart `deploy/helm/kie-runtime` renderiza somente um Deployment e um Service `ClusterIP` para a aplicação BPMN standalone. Ele utiliza a imagem local já validada e não inclui Ingress, banco de dados, operador, Kafka, Route, upload service ou Secrets.

## Estrutura

```text
deploy/helm/kie-runtime/
├── Chart.yaml
├── values.yaml
├── values-local.yaml
├── .helmignore
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    └── NOTES.txt
```

## Valores padrão

| Configuração | Padrão |
| --- | --- |
| Réplicas | `1` |
| Imagem | `kie-runtime-local:dev` |
| Pull policy | `IfNotPresent` |
| Service | `ClusterIP` |
| Porta do Service | `8080` |
| Porta do container | `8080` |
| Liveness | `GET /q/health` |
| Readiness | `GET /q/health` |
| Usuário/grupo | `1001:1001`, não-root |
| CPU request/limit | `100m` / `500m` |
| Memória request/limit | `256Mi` / `768Mi` |

O `values.yaml` permite configurar `replicaCount`, imagem, pull policy, Service, porta do container, recursos, probes, contextos de segurança, `extraEnv`, `nameOverride` e `fullnameOverride`.

O namespace não é fixado em nenhum template ou arquivo de valores. `metadata.namespace` recebe `.Release.Namespace`, fornecido por `--namespace` ou pela futura integração com Skaffold.

## Validar

A partir da raiz do repositório:

```bash
helm lint deploy/helm/kie-runtime

helm template kie-runtime \
  deploy/helm/kie-runtime \
  --namespace kie-dev \
  -f deploy/helm/kie-runtime/values-local.yaml
```

Resultado do lint em 2026-07-27, com Helm 4.2.3:

```text
==> Linting deploy/helm/kie-runtime
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

A recomendação de ícone é informativa e não representa falha.

## Inspeção do render

O YAML renderizado foi validado também com `kubectl create --dry-run=client`. Resultado:

- um Deployment e um Service, sem recursos duplicados;
- nenhum `<no value>`, `null` ou string vazia;
- imagem `kie-runtime-local:dev`;
- `imagePullPolicy: IfNotPresent`;
- namespace renderizado `kie-dev`, recebido de `--namespace`;
- nenhuma ocorrência literal de `kie-dev` nos templates ou values;
- porta 8080 no Service e no container;
- ambas as probes apontando para `/q/health`;
- labels `app.kubernetes.io/name` e `app.kubernetes.io/instance` iguais nos selectors do Deployment, Pod e Service;
- `allowPrivilegeEscalation: false`, capabilities removidas e execução não-root.

## Uso local futuro

Antes de uma futura instalação no Kind, a imagem deve estar disponível no cluster:

```bash
kind load docker-image kie-runtime-local:dev --name kie-local
```

Este chart não foi instalado durante esta etapa.

O cluster atualmente possui Deployment e Service com os mesmos nomes, criados pelos manifestos Kustomize de `app/k8s`. Uma futura migração para Helm deve tratar a propriedade desses recursos de maneira explícita; instalar o chart diretamente sobre recursos não gerenciados pelo Helm pode falhar por conflito de ownership. Nenhum desses recursos foi alterado nesta etapa.
