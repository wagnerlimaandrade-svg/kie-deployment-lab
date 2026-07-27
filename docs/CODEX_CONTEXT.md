# Contexto do laboratório KIE local

## Objetivo geral

Construir, em etapas verificáveis, um laboratório local de Apache KIE sobre Quarkus para compilar e executar modelos BPMN e DMN em Kubernetes local. O ponto de partida é o sample oficial de Dev Deployment do checkout irmão de KIE Tools; o laboratório deverá resultar em uma aplicação chamada `kie-runtime`, uma imagem local e uma implantação reproduzível, sem alterar o código usado como referência.

## Nomes e valores definidos

| Item | Valor |
| --- | --- |
| Cluster | `kie-local` |
| Namespace | `kie-dev` |
| Aplicação | `kie-runtime` |
| Imagem local | `kie-runtime-local:dev` |
| Porta HTTP | `8080` |

## Estrutura de diretórios

```text
kie-local/
├── kie-deployment-lab/              # este repositório
│   ├── app/                         # futura aplicação Quarkus standalone
│   ├── models/                      # modelos BPMN/DMN selecionados
│   ├── kind/                        # configuração futura do cluster local
│   ├── deploy/
│   │   └── helm/
│   │       └── kie-runtime/         # futuro chart da aplicação
│   └── docs/                        # contexto e auditorias
└── upstream-kie-tools/              # checkout oficial, somente leitura
```

O caminho relativo esperado para o upstream, partindo da raiz deste repositório, é `../upstream-kie-tools`.

## Regra de isolamento do upstream

- `../upstream-kie-tools` é uma fonte de referência somente leitura.
- Nenhum arquivo ou diretório do upstream pode ser editado, formatado, gerado ou removido.
- Builds que produzam `target/`, `.mvn/`, wrappers ou outros artefatos não devem ser executados dentro do upstream.
- A extração para `app/` só pode ocorrer em uma etapa posterior e deve registrar os caminhos de origem e as adaptações realizadas.
- Versões de Java, Quarkus, Kogito, KIE e jBPM devem vir de evidência no upstream ou de uma versão oficial publicada explicitamente verificada; não devem ser presumidas.

## Ordem das etapas

1. Auditar o sample oficial e seus acoplamentos ao monorepositório, sem copiar código.
2. Resolver a disponibilidade das dependências e definir versões standalone verificáveis.
3. Extrair o mínimo necessário para `app/`, fixar a configuração Maven e preparar ou recriar o Maven Wrapper.
4. Adicionar modelos BPMN/DMN oficiais e validar compilação, inicialização e endpoints localmente.
5. Criar e validar a imagem `kie-runtime-local:dev`.
6. Criar o cluster `kie-local` e o namespace `kie-dev`.
7. Criar e validar o Helm Chart de `kie-runtime`.
8. Integrar o fluxo de desenvolvimento com Skaffold e executar o teste ponta a ponta.

Esta etapa cobre apenas o item 1.
