# Auditoria do Dev Deployment Quarkus Blank App

## Escopo e procedência

Auditoria realizada em 2026-07-27, sem executar build e sem modificar o upstream.

| Item | Valor |
| --- | --- |
| Checkout | `../upstream-kie-tools` |
| Branch | `main` |
| Commit | `3222b7f8c49d58dada7b1b9600a3778920089d98` |
| Estado observado | limpo (`git status --short` sem saída) |
| Sample | `packages/dev-deployment-quarkus-blank-app` |
| Imagem oficial | `packages/dev-deployment-quarkus-blank-app-image` |

O diretório do sample contém apenas `pom.xml`, `package.json`, `install.js`, `env/index.js`, `README.md`, um arquivo `.iml` e `src/main/resources/application.properties`. Não há BPMN, DMN, código Java, `.mvn/`, `mvnw` ou `mvnw.cmd` versionado nesse diretório.

## Versões exatas

### Java, Maven, Quarkus e linha KIE

| Componente | Versão | Evidência |
| --- | --- | --- |
| Java de compilação | `17` | `<maven.compiler.release>17</maven.compiler.release>` no POM do sample |
| Quarkus | `3.27.4.1` | `QUARKUS_PLATFORM_version` em `packages/root-env/env/index.js`, injetada como `version.quarkus` |
| Kogito | `999-20260616-local` | `KOGITO_RUNTIME_version` em `packages/root-env/env/index.js`, injetada como `version.org.kie.kogito` |
| KIE | `999-20260616-local` | artefatos `org.kie` geridos pelo BOM e metadados locais do checkout usam a mesma linha |
| jBPM | `999-20260616-local` | artefatos `org.jbpm`, incluindo `jbpm-with-drools-quarkus`, usam a mesma linha |
| Maven Wrapper Plugin | `3.3.0` | `packages/maven-base/env/index.js` |
| Maven solicitado pelo wrapper | `3.9.11` | `packages/maven-base/env/index.js` e `-Dmaven=3.9.11` no Containerfile |
| Versão do projeto do sample | `0.0.0` | `package.json`; injetada no POM como `revision` |

Não há propriedades independentes `version.kie` ou `version.jbpm` no sample. KIE, jBPM e Kogito são alinhados pelo `org.kie.kogito:kogito-apps-quarkus-bom:${version.org.kie.kogito}`. Os metadados Maven locais observados para `org.kie:kie-dmn-openapi` e `org.jbpm:jbpm-with-drools-quarkus`, entre outros, registram `999-20260616-local`.

O Java instalado na máquina durante a auditoria era 21, mas isso não altera o requisito do projeto: o bytecode é compilado com release 17. Portanto, o requisito conservador para o laboratório é JDK 17 ou superior capaz de produzir `--release 17`.

### Plugins e overrides declarados no POM

| Propriedade | Versão |
| --- | --- |
| `version.codehaus.flatten.plugin` | `1.6.0` |
| `version.maven.clean.plugin` | `3.4.0` |
| `version.maven.compiler.plugin` | `3.13.0` |
| `version.maven.surefire.plugin` | `3.5.0` |
| `version.maven.failsafe.plugin` | `${version.maven.surefire.plugin}`, portanto `3.5.0` |
| `version.maven.jar.plugin` | `3.4.2` |
| `version.maven.resources.plugin` | `3.3.1` |
| `version.maven.site.plugin` | `3.21.0` |
| `version.junit` | `4.13.2` |
| `version.org.apache.commons.commons-compress` | `1.28.0` |
| `version.org.iq80.snappy` | `0.5` |
| `version.commons-io` | `2.20.0` |
| `version.com.google.protobuf` | `3.25.5` |
| `version.io.netty` | `4.1.135.Final` |
| `version.angus.mail` | `2.0.5` |

O POM também fixa UTF-8, `maven.compiler.parameters=true` e `quarkus.analytics.disabled=true`. Protobuf, Commons Compress, Angus Mail, Netty e dependências de plugins são overrides explícitos, em sua maioria documentados no próprio POM como correções de vulnerabilidades transitivas.

## Propriedades Maven injetadas pelo monorepositório

`packages/dev-deployment-quarkus-blank-app/install.js` chama `setupMavenConfigFile(..., { ignoreDefault: true })`. Isso gera `.mvn/maven.config` com:

```text
--batch-mode
-Dstyle.color=always
-Drevision=0.0.0
-Dversion.quarkus=3.27.4.1
-Dversion.org.kie.kogito=999-20260616-local
-Dmaven.repo.local.tail=<lista absoluta calculada dos repositórios Maven dos pacotes workspace>
```

O valor de `maven.repo.local.tail` é calculado por `buildTailFromPackageJsonDependencies()` em `packages/maven-base/index.js`. Ele percorre recursivamente as dependências `workspace:*` do `package.json` e concatena diretórios `dist/1st-party-m2/repository`. Assim, o valor é específico ao checkout e não pode ser levado literalmente para um projeto standalone.

Como `ignoreDefault: true` é usado, este sample não recebe o `--settings=<packages/maven-base/settings.xml>` presente na configuração padrão do `maven-base`. O comentário do `install.js` informa que isso é intencional para evitar repositórios especiais que só funcionam dentro do monorepositório.

O POM não declara parent do `maven-base` nem parent Apache, justamente para representar uma aplicação consumidora. Mesmo assim, seu funcionamento no commit auditado depende da configuração gerada e dos repositórios Maven locais.

## Dependências funcionais do POM

O BOM importado é:

```text
org.kie.kogito:kogito-apps-quarkus-bom:999-20260616-local
```

Os blocos funcionais declarados são:

- Quarkus RESTEasy, Jackson, multipart, SmallRye OpenAPI e SmallRye Health;
- `org.kie:kie-dmn-openapi`;
- `org.jbpm:jbpm-with-drools-quarkus`, excluindo `org.kie.kogito:kogito-ruleunits`;
- persistência JDBC com H2, Agroal e `kie-addons-quarkus-persistence-jdbc`;
- Data Index embutido JPA;
- Jobs Service embutido com storage JPA;
- persistência JPA de user tasks do jBPM;
- process management e jobs management;
- Quarkus JUnit 5, REST Assured e JUnit 4 para testes.

## Comandos oficiais

### Compilação

No `package.json` do sample:

```text
pnpm build:dev
```

Em Linux/macOS, esse script executa exatamente:

```text
mvn clean install -DskipTests
```

O build de produção executa lint e:

```text
mvn clean install -DskipTests=$(build-env tests.run --not) -Dmaven.test.failure.ignore=$(build-env tests.ignoreFailures)
```

Esses comandos pressupõem que o `install.js` já gerou `.mvn/maven.config` e o wrapper.

### Inicialização em desenvolvimento

No `package.json`:

```text
pnpm quarkus:dev
```

Em Linux/macOS, ele executa:

```text
mvn clean package quarkus:dev -DskipTests
```

A imagem oficial inicia a aplicação em modo dev com:

```text
./mvnw -Dmaven=3.9.11 quarkus:dev -o \
  -s=/tmp/kogito/.m2/settings.xml \
  -Dquarkus.analytics.disabled=true \
  -Ddebug=false \
  -Dmaven.repo.local=/tmp/kogito/.m2/repository \
  -Dquarkus.http.root-path=${ROOT_PATH}
```

Antes disso, o Containerfile pré-popula o repositório Maven local com `./mvnw -Dmaven=3.9.11 clean package ...`.

## Local dos modelos

O README do sample e o `<resources>` do POM definem:

```text
src/main/resources/
```

Arquivos `.dmn`, `.bpmn` e `.bpmn2` podem ficar diretamente nesse diretório ou em subdiretórios quando relações como imports DMN preservarem os caminhos relativos. Na imagem, uploads são extraídos em `$HOME_PATH/app/src/main/resources`, que o README descreve como `/app/src/main/resources`.

## Configuração e endpoints esperados

`src/main/resources/application.properties`:

- escuta em `0.0.0.0`;
- usa a porta padrão do Quarkus, `8080`;
- inclui Swagger UI também fora do modo dev;
- habilita CORS para todas as origens;
- desabilita Dev Services e OIDC;
- aponta service URL, jobs service e Data Index para a própria aplicação;
- habilita Data Index GraphQL UI;
- usa H2 em memória, persistência JDBC e migração KIE Flyway.

Com root path `/`, os endpoints de plataforma esperados são:

| Função | Endpoint |
| --- | --- |
| Health agregado | `http://localhost:8080/q/health` |
| Liveness | `http://localhost:8080/q/health/live` |
| Readiness | `http://localhost:8080/q/health/ready` |
| Startup | `http://localhost:8080/q/health/started` |
| OpenAPI | `http://localhost:8080/q/openapi` |
| Swagger UI | `http://localhost:8080/q/swagger-ui/` |

O Containerfile confirma `/q/health` como fallback do `HEALTHCHECK`; o primeiro teste do healthcheck é `/upload-status`, pertencente ao upload service da imagem e não à aplicação Quarkus standalone. Se `quarkus.http.root-path`/`ROOT_PATH` for alterado, o prefixo configurado deve anteceder `/q/...`.

Endpoints de negócio BPMN/DMN só serão gerados depois que os modelos forem adicionados; seus caminhos derivam dos IDs/nomes dos modelos e devem ser confirmados pelo documento OpenAPI gerado, não presumidos nesta etapa.

## Empacotamento

O POM não define `<packaging>`, portanto o packaging Maven é `jar`. Ele também não sobrescreve o tipo de JAR do Quarkus. O resultado esperado do build Quarkus é o formato padrão fast-jar:

```text
target/quarkus-app/
├── app/
├── lib/
├── quarkus/
└── quarkus-run.jar
```

A forma de execução é:

```text
java -jar target/quarkus-app/quarkus-run.jar
```

Esse formato é corroborado pelos exemplos Quarkus do mesmo checkout, que documentam exatamente esse caminho. O Containerfile auditado não executa o fast-jar: ele preserva o projeto e inicia `quarkus:dev` para permitir recompilação após upload de modelos.

## Maven Wrapper

O wrapper não está versionado no diretório auditado. `install.js` chama `installMvnw()`, que executa:

```text
mvn -e org.apache.maven.plugins:maven-wrapper-plugin:3.3.0:wrapper \
  -Dmaven=3.9.11 \
  -P-include-1st-party-dependencies \
  --settings=<caminho-do-monorepo>/packages/maven-base/settings.xml
```

Conclusão: no estado atual do checkout, o wrapper não pode simplesmente ser copiado do source do sample; ele precisa ser recriado para o projeto standalone, usando Maven Wrapper Plugin `3.3.0` e Maven `3.9.11`, ou copiado de um pacote já materializado e depois verificado. A recriação standalone não deve carregar o `settings.xml` nem os caminhos absolutos do monorepositório sem uma razão explícita.

## Arquivos indispensáveis para um projeto independente

Mínimo de aplicação:

```text
pom.xml
src/main/resources/application.properties
src/main/resources/<modelos .dmn/.bpmn/.bpmn2>
```

Configuração obrigatória adicional: `revision`, `version.quarkus` e `version.org.kie.kogito` precisam ser definidas de maneira independente. Elas podem ser fixadas no POM ou fornecidas por uma `.mvn/maven.config` standalone; deixar essas três propriedades indefinidas torna o POM inválido para o objetivo.

Para builds por wrapper, também são indispensáveis os arquivos gerados:

```text
mvnw
mvnw.cmd
.mvn/wrapper/maven-wrapper.properties
```

Dependendo do formato produzido pelo Wrapper Plugin, `.mvn/wrapper/maven-wrapper.jar` também pode existir. `package.json`, `install.js`, `env/`, `.iml` e o `maven.repo.local.tail` não são necessários no standalone após as propriedades e o wrapper serem materializados. README e arquivos de licença devem acompanhar a extração conforme a política do laboratório e a revisão de licenças.

## Samples oficiais recomendados para o primeiro teste

### BPMN

`packages/jbpm-quarkus-devui/dev/src/main/resources/hiring.bpmn`

Motivos:

- é exercitado pelo app Quarkus de desenvolvimento de jBPM no mesmo checkout e na mesma linha de versões;
- é executável (`isExecutable="true"`) e usa tipos simples, script tasks e user tasks;
- não importa classes `org.acme` externas;
- permite validar geração de API, persistência e user tasks.

Os formulários em `custom-forms-dev/` e o SVG existentes ao lado são recursos da experiência Dev UI, não requisitos para compilar o BPMN no primeiro smoke test.

### DMN

`packages/jbpm-quarkus-devui/dev/src/main/resources/loan-pre-qualification.dmn`

Motivos:

- é o DMN usado pelo app Quarkus oficial de desenvolvimento no mesmo checkout;
- é autocontido, sem import de outro arquivo DMN;
- tem inputs e decisões suficientes para validar geração do endpoint e OpenAPI.

Há cópias muito próximas em `packages/online-editor/static/samples/Sample.bpmn` e `Sample.dmn`, mas usar a dupla do app `jbpm-quarkus-devui/dev` reduz a distância em relação ao runtime auditado. `examples/process-compact-architecture/hiring.bpmn` não é recomendado isoladamente porque importa classes Java `org.acme.CandidateData` e `org.acme.Offer` e chama `NewHiringOffer.dmn`. O modelo `examples/dmn-editor-standalone-on-webapp/static/models/can-drive.dmn` também não é arquivo único: importa `./path1/can-drive-types.dmn`.

## Dependências do monorepositório

### Durante instalação/build por pnpm

- `@kie-tools/root-env` fornece Quarkus e Kogito.
- `@kie-tools/maven-base` cria `.mvn/maven.config` e o Maven Wrapper.
- `@kie-tools/jbpm-quarkus-devui` e suas dependências participam da cauda de repositórios Maven locais.
- `@kie-tools-scripts/build-env` compõe as variáveis de ambiente.
- `run-script-os` seleciona comandos por sistema operacional.
- `pnpm workspace:*`, `node_modules` e os `dist/1st-party-m2/repository` ligam o package ao monorepositório.

### Durante criação da imagem oficial

`packages/dev-deployment-quarkus-blank-app-image` depende ainda de:

- `dev-deployment-base-image`;
- `maven-m2-repo-via-http-image`;
- `image-builder`;
- Docker, `envsubst`, scripts pnpm e um repositório Maven servido temporariamente por HTTP;
- `dev-deployment-upload-service`, fornecido pela imagem base.

O `copy:quarkus-app` remove `node_modules`, `install.js`, `env/` e `package.json` da cópia destinada à imagem, confirmando que esses arquivos são scaffolding do monorepositório, não runtime da aplicação.

## Avaliação de extração standalone

É seguro extrair a estrutura do sample como base conceitual: o POM foi intencionalmente escrito sem parent do monorepositório e os scripts Node podem ser eliminados após materializar a configuração Maven.

Não é ainda seguro declarar o resultado como standalone reproduzível em ambiente limpo no commit auditado. A versão exata `999-20260616-local` é local, e a resolução observada depende de `maven.repo.local.tail` e dos artefatos construídos pelo monorepositório. Antes da extração operacional, é necessário escolher uma destas estratégias:

1. identificar e verificar uma versão oficial publicada e compatível para substituir a versão local; ou
2. preservar/provisionar de forma reproduzível o repositório Maven contendo os artefatos `999-20260616-local`.

Remover apenas `maven.repo.local.tail`, mantendo `999-20260616-local`, não produz um standalone confiável.

## Dúvidas e dependências não resolvidas

- Qual versão oficial publicada substituirá `999-20260616-local`, caso o laboratório não distribua o repositório Maven local?
- Todos os artefatos necessários dessa versão estarão disponíveis em repositórios públicos, inclusive Kogito Apps, KIE e jBPM?
- O laboratório manterá o conjunto completo de persistência/Data Index/Jobs/user tasks do sample ou adotará um POM mínimo?
- O root path final permanecerá `/`? Essa decisão afeta health, OpenAPI, Swagger e endpoints de negócio.
- O primeiro teste BPMN deverá validar apenas criação de processo ou também o ciclo completo de user task?
- Será exigida cópia dos notices/licenças dos modelos e do sample além dos cabeçalhos já presentes? O README upstream recomenda revisão de licenças.
- A recriação do wrapper e seus checksums deve ser validada depois que a estratégia de repositórios Maven estiver definida.
