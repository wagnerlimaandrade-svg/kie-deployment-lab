# Execução local em container

Este documento descreve a execução containerizada da aplicação BPMN existente. A imagem contém somente o processo `hello.bpmn`; nenhum modelo DMN ou processo adicional é incluído.

## Pré-requisitos

- Docker Engine com suporte a Docker Compose;
- acesso à internet no primeiro build para baixar as imagens base e as dependências do Maven Central;
- JDK 21 apenas para executar o build Maven diretamente no host.

Versões fixadas pelo projeto:

| Componente | Versão |
| --- | --- |
| Java | 21 |
| Quarkus | 3.27.2 |
| Apache KIE, jBPM e Drools | 10.2.0 |
| Maven Wrapper | 3.9.11 |
| Imagem de build | `maven:3.9.11-eclipse-temurin-21` |
| Imagem de execução | `eclipse-temurin:21-jre-jammy` |

## Gerar o pacote

A partir do diretório `app/`:

```bash
./mvnw clean package
```

O projeto produz um Quarkus fast-jar. O lançador fica em `target/quarkus-app/quarkus-run.jar` e depende dos demais arquivos desse mesmo diretório.

## Construir a imagem

```bash
docker compose build
```

O build multi-stage recompila a aplicação dentro da imagem usando o Maven Wrapper e baixa as dependências do Maven Central. Ele não utiliza o diretório `target/` nem o repositório Maven local do host. A imagem resultante é `kie-runtime-local:dev`.

## Iniciar e verificar

```bash
docker compose up -d
docker compose ps
```

A porta `8080` do container é publicada somente em `127.0.0.1:8080`. O serviço executa como o usuário não-root `kie`, UID/GID `1001:1001`. O estado de saúde é verificado pelo endpoint real `GET /q/health`.

## Testar o processo

O processo não declara variáveis de entrada; portanto, o corpo correto é um objeto JSON vazio:

```bash
curl -i -X POST http://localhost:8080/hello \
  -H "Content-Type: application/json" \
  -d '{}'
```

Resposta validada (o UUID varia a cada execução):

```http
HTTP/1.1 201 Created
Content-Type: application/json
Location: http://localhost:8080/hello/<UUID-gerado>

{"id":"<UUID-gerado>"}
```

O log da aplicação também registra `Hello from the KIE local runtime`, produzido pela tarefa de script já existente em `hello.bpmn`.

Endpoints disponíveis:

| Recurso | Método e URL |
| --- | --- |
| Iniciar o processo | `POST http://localhost:8080/hello` |
| Health | `GET http://localhost:8080/q/health` |
| OpenAPI | `GET http://localhost:8080/q/openapi` |
| Swagger UI | `GET http://localhost:8080/q/swagger-ui/` |

## Logs

Para acompanhar continuamente:

```bash
docker compose logs -f
```

Para uma consulta sem códigos de cor:

```bash
docker compose logs --no-color
```

## Encerrar

```bash
docker compose down
```

## Reconstruir após alterações

```bash
./mvnw clean package
docker compose build
docker compose up -d
docker compose ps
```

Use `docker compose build --no-cache` apenas quando for necessário invalidar também o cache das imagens e das dependências.

## Limitações conhecidas

- A aplicação possui somente o processo efêmero `hello`; não há persistência externa.
- Não há DMN, mensageria, banco de dados ou outros serviços no Compose.
- A primeira construção exige acesso ao Maven Central e aos registries das imagens base.
- A publicação fixa em `127.0.0.1:8080` pressupõe que a porta 8080 esteja livre no host.
