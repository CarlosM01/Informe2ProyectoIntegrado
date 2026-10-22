#!/bin/bash
# Sourced by the mongo image entrypoint on first start (empty volume).
# The subshell keeps the entrypoint's working directory and options intact;
# mongo_init.js must run from /bd because it reads mongo_esquemas.json relatively.
(cd /bd && mongosh --quiet "mongodb://localhost:27017/sgp_docs" --file mongo_init.js)
