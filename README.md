# KIE Deployment Lab

Laboratório local para executar runtimes KIE em um cluster Kind usando
Skaffold e Helm.

## Início rápido

Para o runtime local incluído em `app/`:

```bash
skaffold run
scripts/test-deployment.sh
```

Para simular o Dev Deployment do Web Editor, com upload de BPMN/DMN:

```bash
export DEV_DEPLOYMENT_UPLOAD_API_KEY='<chave-local-forte>'
scripts/deploy-official.sh
```

Consulte:

- [`docs/LOCAL_DEPLOYMENT.md`](docs/LOCAL_DEPLOYMENT.md) para o runtime fixo;
- [`docs/OFFICIAL_IMAGE.md`](docs/OFFICIAL_IMAGE.md) para o playbook completo
  de upload e compilação offline.
