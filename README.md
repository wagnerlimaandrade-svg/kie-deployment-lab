# KIE Deployment Lab

Laboratório local para executar runtimes KIE em um cluster Kind usando
Skaffold e Helm.

## Independência do KIE Tools

O build e a inicialização não acessam um checkout local do repositório Apache
KIE Tools. O runtime de `app/` usa artefatos publicados no Maven Central. O
perfil `official` e o Web Editor usam imagens publicadas do Apache KIE Sandbox,
portanto permanecem dependentes desses artefatos upstream e de seus registries,
mas não do source tree `upstream-kie-tools`.

As imagens do fluxo oficial usam atualmente a tag mutável `main`; para builds
totalmente reprodutíveis, elas ainda precisam ser fixadas por digest.

## Início rápido

Para o runtime local incluído em `app/`:

```bash
skaffold run
bash scripts/test-deployment.sh
```

Para simular o Dev Deployment do Web Editor, com upload de BPMN/DMN:

```bash
export DEV_DEPLOYMENT_UPLOAD_API_KEY='<chave-local-forte>'
bash scripts/deploy-official.sh
```

Para iniciar o KIE Sandbox publicado e conectá-lo ao cluster do lab pela mesma
origem usada pelos runtimes:

```bash
bash scripts/start-web-editor.sh
```

Consulte:

- [`docs/LOCAL_DEPLOYMENT.md`](docs/LOCAL_DEPLOYMENT.md) para o runtime fixo;
- [`docs/OFFICIAL_IMAGE.md`](docs/OFFICIAL_IMAGE.md) para o playbook completo
  de upload e compilação offline;
- [`docs/WEB_EDITOR.md`](docs/WEB_EDITOR.md) para a integração do editor web
  com o runtime do lab;
- [`docs/WINDOWS.md`](docs/WINDOWS.md) para execução em Windows com Git Bash.
