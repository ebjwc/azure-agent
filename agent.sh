#!/bin/bash
docker run \
 -e VSTS_ACCOUNT=<ACCOUNT> \
 -e VSTS_TOKEN=<PAT> \
 -e VSTS_POOL=<POOL> \
 -e VSTS_AGENT=<AGENT> \
 -it jhageste/azure-agent