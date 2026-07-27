#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

FROM maven:3.9.11-eclipse-temurin-21 AS build

WORKDIR /workspace

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
COPY src/main/ src/main/

RUN ./mvnw --batch-mode -Dmaven.test.skip=true clean package

FROM eclipse-temurin:21-jre-jammy AS runtime

RUN apt-get update \
    && apt-get install --yes --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 kie \
    && useradd --system --uid 1001 --gid kie --home-dir /opt/kie --shell /usr/sbin/nologin kie

WORKDIR /opt/kie

COPY --from=build --chown=1001:1001 /workspace/target/quarkus-app/app/ app/
COPY --from=build --chown=1001:1001 /workspace/target/quarkus-app/lib/ lib/
COPY --from=build --chown=1001:1001 /workspace/target/quarkus-app/quarkus/ quarkus/
COPY --from=build --chown=1001:1001 /workspace/target/quarkus-app/quarkus-app-dependencies.txt ./
COPY --from=build --chown=1001:1001 /workspace/target/quarkus-app/quarkus-run.jar ./

ENV QUARKUS_HTTP_HOST=0.0.0.0 \
    QUARKUS_HTTP_PORT=8080

USER 1001:1001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
