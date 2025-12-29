#!/usr/bin/env bash
# exit on error
set -o errexit

mix deps.get --only prod
MIX_ENV=prod mix compile

# run migrations
MIX_ENV=prod mix ecto.migrate

# build assets
MIX_ENV=prod mix assets.deploy

# build release
MIX_ENV=prod mix release