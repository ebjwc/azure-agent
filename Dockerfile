FROM ubuntu:16.04

# PART 1 - Agent ----------------------------------------------------------------------------------

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

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]

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

# Install Ansible
RUN apt-get update \   
 && apt-get install -y --no-install-recommends \
    ansible \      
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

# Install Clang (only appears to work on xenial)
RUN [ "xenial" = "xenial" ] \
 && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
 && apt-add-repository "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-6.0 main" \
 && apt-get update \
 && apt-get install -y --no-install-recommends clang-6.0 \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/* \
 || echo -n

# Install CMake
RUN curl -sL https://cmake.org/files/v3.10/cmake-3.10.2-Linux-x86_64.sh -o cmake.sh \
 && chmod +x cmake.sh \
 && ./cmake.sh --prefix=/usr/local --exclude-subdir \
 && rm cmake.sh

# Install Erlang
RUN echo "deb http://binaries.erlang-solutions.com/debian xenial contrib" > /etc/apt/sources.list.d/eslerlang.list \
 && wget -O - http://binaries.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add - \
 && apt-get update \
 && apt-get install -y --no-install-recommends esl-erlang \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# Install Go
RUN curl -sL https://dl.google.com/go/go1.9.4.linux-amd64.tar.gz -o go1.9.4.linux-amd64.tar.gz \
 && mkdir -p /usr/local/go1.9.4 \
 && tar -C /usr/local/go1.9.4 -xzf go1.9.4.linux-amd64.tar.gz --strip-components=1 go \
 && rm go1.9.4.linux-amd64.tar.gz
RUN curl -sL https://dl.google.com/go/go1.10.linux-amd64.tar.gz -o go1.10.linux-amd64.tar.gz \
 && mkdir -p /usr/local/go1.10 \
 && tar -C /usr/local/go1.10 -xzf go1.10.linux-amd64.tar.gz --strip-components=1 go \
 && rm go1.10.linux-amd64.tar.gz
ENV GOROOT_1_9_X64=/usr/local/go1.9.4 \
    GOROOT_1_10_X64=/usr/local/go1.10 \
    GOROOT=/usr/local/go1.10
ENV PATH $PATH:$GOROOT/bin

# Install Haskell
RUN apt-get update \
 && apt-get install -y haskell-platform \
 && rm -rf /var/lib/apt/lists/*

# Install Helm
RUN curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

# Install HHVM
RUN apt-get update \
 && apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xB4112585D386EB94 \
 && add-apt-repository https://dl.hhvm.com/ubuntu \
 && apt-get update \
 && apt-get install -y hhvm \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# Install ImageMagick
RUN apt-get update \
 && apt-get install -y --no-install-recommends --fix-missing \
    imagemagick \
    libmagickcore-dev \
    libmagickwand-dev \
    libmagic-dev \
 && rm -rf /var/lib/apt/lists/*

# Install Java OpenJDKs
RUN apt-add-repository -y ppa:openjdk-r/ppa
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-7-jdk \
 && rm -rf /var/lib/apt/lists/*
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-8-jdk \
 && rm -rf /var/lib/apt/lists/*
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-9-jdk \
 && rm -rf /var/lib/apt/lists/*
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-10-jdk \
 && rm -rf /var/lib/apt/lists/*
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-11-jdk \
 && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
ENV JAVA_HOME_7_X64=/usr/lib/jvm/java-7-openjdk-amd64 \
    JAVA_HOME_8_X64=/usr/lib/jvm/java-8-openjdk-amd64 \
    JAVA_HOME_9_X64=/usr/lib/jvm/java-9-openjdk-amd64 \
    JAVA_HOME_10_X64=/usr/lib/jvm/java-10-openjdk-amd64 \
    JAVA_HOME_11_X64=/usr/lib/jvm/java-11-openjdk-amd64 \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

# Install Java Tools (Ant, Gradle, Maven)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ant \
    ant-optional \
 && rm -rf /var/lib/apt/lists/*
RUN curl -sL https://services.gradle.org/distributions/gradle-4.6-bin.zip -o gradle-4.6.zip \
 && unzip -d /usr/share gradle-4.6.zip \
 && ln -s /usr/share/gradle-4.6/bin/gradle /usr/bin/gradle \
 && rm gradle-4.6.zip
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    maven \
 && rm -rf /var/lib/apt/lists/*
ENV ANT_HOME=/usr/share/ant \
    GRADLE_HOME=/usr/share/gradle \
    M2_HOME=/usr/share/maven

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
 && chmod +x ./kubectl \
 && mv ./kubectl /usr/local/bin/kubectl

# Install AzCopy (depends on .NET Core)
RUN apt-key adv --keyserver packages.microsoft.com --recv-keys EB3E94ADBE1229CF \
 && echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod/ xenial main" | tee /etc/apt/sources.list.d/azure.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends azcopy \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# Install LTS Node.js and related tools
RUN curl -sL https://git.io/n-install | bash -s -- -ny - \
 && ~/n/bin/n lts \
 && npm install -g bower \
 && npm install -g grunt \
 && npm install -g gulp \
 && npm install -g n \
 && npm install -g webpack webpack-cli --save-dev \
 && npm install -g parcel-bundler \
 && npm i -g npm \
 && rm -rf ~/n
ENV bower=/usr/local/bin/bower \
    grunt=/usr/local/bin/grunt

# Install PhantomJS
RUN apt-get update \
 && apt-get install -y chrpath libssl-dev libxft-dev libfreetype6 libfreetype6-dev libfontconfig1 libfontconfig1-dev \
 && rm -rf /var/lib/apt/lists/* \
 && export PHANTOM_JS=phantomjs-2.1.1-linux-x86_64 \
 && wget https://bitbucket.org/ariya/phantomjs/downloads/$PHANTOM_JS.tar.bz2 \
 && tar xvjf $PHANTOM_JS.tar.bz2 \
 && mv $PHANTOM_JS /usr/local/share \
 && ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/bin

# Install Pollinate
RUN apt-get update \
 && apt-get install -y --no-install-recommends pollinate \
 && rm -rf /var/lib/apt/lists/*

# Install Powershell Core
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
 && curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | tee /etc/apt/sources.list.d/microsoft.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    powershell \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# Install rebar3 (for Erlang)
RUN wget -q -O rebar3 https://s3.amazonaws.com/rebar3/rebar3 \
 && chmod +x rebar3 \
 && mv rebar3 /usr/local/bin/rebar3

# Install Ruby requirements
RUN apt-get update \
 && apt-get install -y libz-dev openssl libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# Install Scala build tools
RUN curl -s https://raw.githubusercontent.com/paulp/sbt-extras/master/sbt > /usr/local/bin/sbt \
 && chmod 0755 /usr/local/bin/sbt

# Install Sphinx
RUN [ "xenial" = "xenial" ] \
  && apt-get update \
  && apt-get install -y sphinxsearch \
  && rm -rf /var/lib/apt/lists/* \
  || echo -n

# Install Terraform
RUN TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version) \
 && curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
 && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin \
 && rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# XSLT transformation
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    xsltproc \
    xalan \
 && rm -rf /var/lib/apt/lists/*

# Install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends yarn \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

# Install Xvfb
RUN apt-get update \
 && apt-get install -y xvfb \
 && rm -rf /var/lib/apt/lists/*

# Download hosted tool cache
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN azcopy --recursive --source https://vstsagenttools.blob.core.windows.net/tools/hostedtoolcache/linux --destination $AGENT_TOOLSDIRECTORY

# Install the tools from the hosted tool cache
RUN original_directory=$PWD \
 && setups=$(find $AGENT_TOOLSDIRECTORY -name setup.sh) \
 && for setup in $setups; do \
        chmod +x $setup; \
        cd $(dirname $setup); \
        ./$(basename $setup); \
        cd $original_directory; \
    done;

# Add the latest Ruby version in the tool cache to the path
ENV PATH $PATH:/opt/hostedtoolcache/Ruby/2.5.1/x64/bin

# Clean system
RUN apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /etc/apt/sources.list.d/*

 # PART 3 - Docker --------------------------------------------------------------------------------

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 17.12.0-ce

RUN set -ex \
 && curl -fL "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/`uname -m`/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
 && tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin \
 && rm docker.tgz \
 && docker -v

ENV DOCKER_COMPOSE_VERSION 1.18.0

RUN set -x \
 && curl -fSL "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m`" -o /usr/local/bin/docker-compose \
 && chmod +x /usr/local/bin/docker-compose \
 && docker-compose -v