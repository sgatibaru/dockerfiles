#!/bin/bash

set -xe

source /usr/local/share/bootstrap/common_functions.sh
source /usr/local/share/env/custom_env_variables
source /usr/local/share/env/default_env_variables
source /usr/local/share/env/bootstrap_env_variables

cd /app || exit 1;

set +e
is_nfs
IS_NFS=$?
set -e

# TODO: Convert to template
if [ ! -f "app/etc/env.php" ]; then
  as_code_owner "cp tools/docker/magento/env.php app/etc/env.php"
  as_code_owner "cp tools/docker/magento/config.php app/etc/config.php"
fi

if [ ! -d "vendor" ] || [ ! -f "vendor/autoload.php" ]; then
  as_code_owner "composer config repositories.magento composer https://repo.magento.com/"
  as_code_owner "composer global config http-basic.repo.magento.com '$MAGENTO_USERNAME' '$MAGENTO_PASSWORD'"
  as_code_owner "composer global config http-basic.toran.inviqa.com '$TORAN_USERNAME' '$TORAN_PASSWORD'"
  as_code_owner "composer global config github-oauth.github.com '$GITHUB_TOKEN'"

  # do not use optimize-autoloader parameter yet, according to github, Mage2 has issues with it
  as_code_owner "composer install --no-interaction"
  rm -rf /home/build/.composer/cache/
  as_code_owner "composer clear-cache"

  chmod -R go-w vendor
  chmod +x bin/magento
fi

if [ "$IS_NFS" -ne 0 ]; then
  chown -R "${APP_USER}:${CODE_GROUP}" pub/media pub/static var
  chmod ug+rw,o-w pub/media pub/static var
else
  chmod a+rw pub/media pub/static var
fi

if [ -d "tools/inviqa" ]; then
  mkdir -p pub/static/frontend/

  if [ -d "pub/static/frontend/" ] && [ "$IS_NFS" -ne 0 ]; then
    chown -R "${CODE_OWNER}:${CODE_GROUP}" pub/static/frontend/
  fi

  if [ ! -d "tools/inviqa/node_modules" ]; then
   as_code_owner "npm install" "tools/inviqa"
  fi
  if [ -z "$GULP_BUILD_THEME_NAME" ]; then
    as_code_owner "gulp build" "tools/inviqa"
  else
    as_code_owner "gulp build --theme='$GULP_BUILD_THEME_NAME'" "tools/inviqa"
  fi

  if [ -d "pub/static/frontend/" ] && [ "$IS_NFS" -ne 0 ]; then
    chown -R "${APP_USER}:${APP_GROUP}" pub/static/frontend/
  fi
fi