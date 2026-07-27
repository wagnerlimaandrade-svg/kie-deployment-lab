# KIE Local Runtime

Aplicação Maven standalone para executar um processo BPMN com Apache KIE/jBPM sobre Quarkus.

## Origem e versões

O projeto foi derivado da estrutura do sample oficial `packages/dev-deployment-quarkus-blank-app` do repositório Apache KIE Tools. A configuração foi tornada independente do monorepositório e usa somente artefatos publicados no Maven Central.

| Componente | Versão |
| --- | --- |
| Java | 21 |
| Apache KIE, jBPM e Drools | 10.2.0 |
| Quarkus | 3.27.2 |
| Maven Wrapper Plugin | 3.3.0 |
| Maven do wrapper | 3.9.11 |

## Pré-requisitos

- JDK 21 disponível em `JAVA_HOME`;
- acesso ao Maven Central no primeiro build.

Não é necessário instalar Maven globalmente: o Maven Wrapper está incluído.

## Estrutura

```text
.
├── pom.xml
├── mvnw
├── mvnw.cmd
├── .mvn/wrapper/
├── src/main/resources/
│   ├── application.properties
│   └── hello.bpmn
└── src/test/java/org/kie/local/KieRuntimeTest.java
```

`hello.bpmn` é um processo mínimo e independente: evento inicial, script task que escreve uma mensagem no console e evento final. Esta etapa não inclui DMN e, portanto, não declara `kie-dmn-openapi`.

## Compilar e testar

```bash
./mvnw clean test
./mvnw clean package
```

O build gera um fast-jar Quarkus em `target/quarkus-app`.

## Executar

```bash
java -jar target/quarkus-app/quarkus-run.jar
```

Para desenvolvimento:

```bash
./mvnw quarkus:dev
```

A aplicação escuta em `0.0.0.0:8080` e não configura root path customizado.

## Iniciar o processo

Com a aplicação em execução:

```bash
curl --fail-with-body \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' \
  http://localhost:8080/hello
```

O endpoint `POST /hello` cria e conclui uma instância do processo.

## Endpoints

| Recurso | URL |
| --- | --- |
| Processo BPMN | `POST http://localhost:8080/hello` |
| Health | `http://localhost:8080/q/health` |
| OpenAPI | `http://localhost:8080/q/openapi` |
| Swagger UI | `http://localhost:8080/q/swagger-ui/` |
