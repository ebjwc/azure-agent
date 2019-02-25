FROM ubuntu:16.04

# PART 1 - General --------------------------------------------------------------------------------

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

# Trusty needs an updated backport of apt to avoid hash sum mismatch errors
RUN [ "xenial" = "trusty" ] \
 && curl -s https://packagecloud.io/install/repositories/computology/apt-backport/script.deb.sh |  bash \
 && apt-get update \
 && apt-get install apt=1.2.10 \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/* \
 || echo -n

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        software-properties-common \
 && apt-add-repository ppa:git-core/ppa \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        apt-utils \
        curl \
        git \
        jq \
        libcurl3 \
        libicu55 \
        libunwind8 \
        netcat \
 && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
 && apt-get install -y --no-install-recommends git-lfs \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# Accept the TEE EULA
RUN mkdir -p "/root/.microsoft/Team Foundation/4.0/Configuration/TEE-Mementos" \
 && cd "/root/.microsoft/Team Foundation/4.0/Configuration/TEE-Mementos" \
 && echo '<ProductIdData><eula-14.0 value="true"/></ProductIdData>' > "com.microsoft.tfs.client.productid.xml"

WORKDIR /vsts

# PART 2 - Libraries ------------------------------------------------------------------------------

# Install basic command-line utilities
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    curl \
    dnsutils \
    file \
    ftp \
    iproute2 \
    iputils-ping \
    locales \
    openssh-client \
    rsync\
    shellcheck \
    sudo \
    telnet \
    time \
    unzip \
    wget \
    zip \
    tzdata \
 && rm -rf /var/lib/apt/lists/*

# Setup the locale
ENV LANG en_US.UTF-8
ENV LC_ALL $LANG
RUN locale-gen $LANG \
 && update-locale

# Accept EULA - needed for certain Microsoft packages like SQL Server Client Tools
ENV ACCEPT_EULA=Y

# Install essential build tools
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# Install Azure CLI (instructions taken from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/azure-cli.list \
 && curl -L https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    apt-transport-https \
    azure-cli \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/* \
 && az --version

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
 && chmod +x ./kubectl \
 && mv ./kubectl /usr/local/bin/kubectl

# Install Java OpenJDKs
ENV JDK_VERSION 8

RUN apt-add-repository -y ppa:openjdk-r/ppa
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    openjdk-${JDK_VERSION}-jdk \
 && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --set java /usr/lib/jvm/java-${JDK_VERSION}-openjdk-amd64/jre/bin/java
ENV JAVA_HOME_8_X64=/usr/lib/jvm/java-${JDK_VERSION}-openjdk-amd64 \
    JAVA_HOME=/usr/lib/jvm/java-${JDK_VERSION}-openjdk-amd64 \
    JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

# Install Gradle and Maven
ENV GRADLE_VERSION 4.6
ENV MAVEN_VERSION 3.6.0

RUN curl -sL https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -o gradle-${GRADLE_VERSION}.zip \
 && unzip -d /usr/share gradle-${GRADLE_VERSION}.zip \
 && ln -s /usr/share/gradle-${GRADLE_VERSION}/bin/gradle /usr/bin/gradle \
 && rm gradle-${GRADLE_VERSION}.zip
RUN curl -sL https://www-us.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip -o apache-maven-${MAVEN_VERSION}.zip \
 && unzip -d /usr/share apache-maven-${MAVEN_VERSION}.zip \
 && ln -s /usr/share/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/bin/mvn \
 && rm apache-maven-${MAVEN_VERSION}.zip
ENV ANT_HOME=/usr/share/ant \
    GRADLE_HOME=/usr/share/gradle-${GRADLE_VERSION} \
    M2_HOME=/usr/share/apache-maven-${MAVEN_VERSION}
COPY ./maven/settings-security.xml /root/.m2/settings-security.xml

# Install ActiveMQ
ENV ACTIVEMQ_VERSION 5.15.6

RUN curl -sL http://archive.apache.org/dist/activemq/${ACTIVEMQ_VERSION}/apache-activemq-${ACTIVEMQ_VERSION}-bin.tar.gz -o apache-activemq-${ACTIVEMQ_VERSION}.tar.gz \
 && tar -xzf apache-activemq-${ACTIVEMQ_VERSION}.tar.gz -C /usr/share \
 && ln -s /usr/share/apache-activemq-${ACTIVEMQ_VERSION}/bin/activemq /usr/bin/activemq \
 && rm apache-activemq-${ACTIVEMQ_VERSION}.tar.gz

# Install PostgreSQL
ENV POSTGRES_VERSION 10

COPY ./postgres/schema.sql .
RUN curl -L https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" \
 | tee /etc/apt/sources.list.d/PostgreSQL.list
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    postgresql-${POSTGRES_VERSION} \
    postgresql-${POSTGRES_VERSION}-postgis-2.4 \
    postgresql-${POSTGRES_VERSION}-postgis-scripts \
    postgresql-client-${POSTGRES_VERSION} \
    postgresql-contrib-${POSTGRES_VERSION} \
    postgis \
 && ln -s /etc/init.d/postgresql /usr/bin/postgresql \
 && rm -rf /var/lib/apt/lists/*
RUN ls /etc/postgresql
USER postgres
RUN echo configure postgres hosts and ports \
 && echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf \
 && echo "listen_addresses='*'" >> /etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf
RUN echo configure postgres password \
 && postgresql start \
 && psql --command "ALTER ROLE postgres WITH PASSWORD 'postgres';" \
 && psql -a -f "schema.sql"
USER root

# Install Graphviz
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    graphviz \
 && rm -rf /var/lib/apt/lists/*

# Install Kafka, Zookeeper and Supervisor
ENV SCALA_VERSION 2.11
ENV KAFKA_VERSION 2.1.1
ENV KAFKA_HOME /usr/share/kafka-${SCALA_VERSION}-${KAFKA_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    zookeeper \
    supervisor \
 && curl -sL http://apache.mirrors.spacedump.net/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -o kafka-${SCALA_VERSION}-${KAFKA_VERSION}.tgz \
 && tar xfz kafka-${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /usr/share \
 && rm kafka-${SCALA_VERSION}-${KAFKA_VERSION}.tgz
ADD kafka/kafka.sh /usr/bin/kafka.sh
RUN chmod +x /usr/bin/kafka.sh
ADD kafka/kafka.conf kafka/zookeeper.conf /etc/supervisor/conf.d/

# Clean system
RUN apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# PART 3 - Docker ---------------------------------------------------------------------------------

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 17.12.0-ce

RUN set -ex \
 && curl -fL "https://download.docker.com/linux/static/$DOCKER_CHANNEL/`uname -m`/docker-$DOCKER_VERSION.tgz" -o docker.tgz \
 && tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin \
 && rm docker.tgz \
 && docker -v

ENV DOCKER_COMPOSE_VERSION 1.18.0

RUN set -x \
 && curl -fSL "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m`" -o /usr/local/bin/docker-compose \
 && chmod +x /usr/local/bin/docker-compose \
 && docker-compose -v

# PART 4 - Capabilities ---------------------------------------------------------------------------

ENV activemq true
ENV postgres true
ENV gradle true
ENV graphviz true
ENV kafka true

# PART 5 - Start ----------------------------------------------------------------------------------

COPY ./agent/start.sh .
RUN chmod +x start.sh
CMD ["./start.sh"]