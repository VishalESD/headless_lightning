#!/usr/bin/env bash

# NAME
#     install.sh - Create the test fixture.
#
# SYNOPSIS
#     install.sh
#
# DESCRIPTION
#     Creates the test fixture and places the SUT.

cd "$(dirname "$0")"

# Reuse ORCA's own includes.
source ../../../orca/bin/travis/_includes.sh

# When testing the SUT in isolation using dev package versions, treat the
# components as part of the SUT, to be installed in an isolated (SUT-only)
# fixture.
if [[ "$ORCA_JOB" == "ISOLATED_DEV" ]]; then
  export ORCA_PACKAGES_CONFIG=../headless_lightning/tests/packages.yml
  orca fixture:init -f --sut="$ORCA_SUT_NAME" --dev --profile=headless_lightning
else
  # Run ORCA's standard installation script.
  ../../../orca/bin/travis/install.sh
fi

# If there is no fixture, there's nothing else for us to do.
[[ -d "$ORCA_FIXTURE_DIR" ]] || exit 0

# Add testing dependencies.
composer -d $ORCA_FIXTURE_DIR require phpspec/prophecy-phpunit:^2

# Exit early if no DB fixture is specified.
[[ "$DB_FIXTURE" ]] || exit 0

cd "$ORCA_FIXTURE_DIR/docroot"

# Ensure the files directory exists so that the default user avatar can be
# copied into it.
mkdir -p ./sites/default/files

DB="$TRAVIS_BUILD_DIR/tests/fixtures/$DB_FIXTURE.php.gz"

php core/scripts/db-tools.php import "$DB"

drush php:script "$TRAVIS_BUILD_DIR/tests/update.php"

drush updatedb --yes
drush update:lightning --no-interaction --yes

orca fixture:enable-extensions

# Reinstall from exported configuration to prove that it's coherent.
drush config:export --yes
drush site:install --yes --existing-config --account-pass admin

drush config:set moderation_dashboard.settings redirect_on_login 1 --yes

# Set the fixture state to reset to between tests.
orca fixture:backup --force
