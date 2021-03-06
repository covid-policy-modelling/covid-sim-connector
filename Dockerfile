# Default version if the variable is not set. The version in the .env file takes precedence.
ARG COVIDSIM_VER=master
FROM ghcr.io/mrc-ide/covid-sim/covidsim:${COVIDSIM_VER} AS covidsim

####################################################################
FROM node:14-buster-slim AS build
# ARGs have to be redefined as they go out-of-scope with each FROM
ARG COVIDSIM_VER=master

# SpatailSim Dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && apt-get clean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Copy and unzip the imperial model data and executables
COPY --from=covidsim /data/input /model/input
COPY --from=covidsim /usr/bin/CovidSim /usr/bin/CovidSim
RUN gunzip /model/input/populations/*.gz \
    && rm -f /model/input/populations/*.gz

WORKDIR /connector

COPY package.json package-lock.json ./
RUN npm install

COPY . .

RUN npm run build

# CovidSim has no way of actually retrieving the installed version number, so have to just repeat the image tag
ENV COVIDSIM_VERSION=${COVIDSIM_VER}
ENV MODEL_RUNNER_BIN_DIR /usr/bin
ENV MODEL_RUNNER_LOG_DIR /data/log
ENV MODEL_DATA_DIR /model/input
ENV MODEL_INPUT_DIR /data/input
ENV MODEL_OUTPUT_DIR /data/output

ENTRYPOINT ["/connector/bin/run-model"]

####################################################################
# Do this here so that we don't have to run the tests when bulding a release.
FROM build AS release

LABEL org.opencontainers.image.source=https://github.com/covid-policy-modelling/covid-sim-connector

####################################################################
FROM build AS test

RUN npm run test
RUN npm run integration-test

####################################################################
# Use release as the default
FROM release
