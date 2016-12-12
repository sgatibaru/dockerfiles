#!/bin/bash

set -xe

source /usr/local/share/bootstrap/common_functions.sh
source /usr/local/share/env/custom_env_variables
source /usr/local/share/env/default_env_variables
source /usr/local/share/env/bootstrap_env_variables

if [ -L "$0" ] ; then
    DIR="$(dirname "$(readlink -f "$0")")" ;
else
    DIR="$(dirname "$0")" ;
fi

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

  if [ -n "$MAGENTO_USERNAME" ]; then
    as_code_owner "composer global config http-basic.repo.magento.com '$MAGENTO_USERNAME' '$MAGENTO_PASSWORD'"
  fi
  if [ -n "$TORAN_USERNAME" ]; then
    as_code_owner "composer global config http-basic.toran.inviqa.com '$TORAN_USERNAME' '$TORAN_PASSWORD'"
  fi
  if [ -n "$GITHUB_TOKEN" ]; then
    as_code_owner "composer global config github-oauth.github.com '$GITHUB_TOKEN'"
  fi

  # do not use optimize-autoloader parameter yet, according to github, Mage2 has issues with it
  as_code_owner "composer install --no-interaction"
  rm -rf /home/build/.composer/cache/
  as_code_owner "composer clear-cache"

  chmod -R go-w vendor
  chmod +x bin/magento
fi

mkdir -p pub/media pub/static var
if [ "$IS_NFS" -ne 0 ]; then
  chown -R "${APP_USER}:${CODE_GROUP}" pub/media pub/static var
  chmod -R ug+rw,o-w pub/media pub/static var
else
  chmod -R a+rw pub/media pub/static var
fi

if [ -d "$FRONTEND_INSTALL_DIRECTORY" ]; then
  mkdir -p pub/static/frontend/

  if [ -d "pub/static/frontend/" ] && [ "$IS_NFS" -ne 0 ]; then
    chown -R "${CODE_OWNER}:${CODE_GROUP}" pub/static/frontend/
  fi

  if [ ! -d "$FRONTEND_INSTALL_DIRECTORY/node_modules" ]; then
    as_code_owner "npm install" "$FRONTEND_INSTALL_DIRECTORY"
  fi
  if [ -z "$GULP_BUILD_THEME_NAME" ]; then
    as_code_owner "gulp $FRONTEND_BUILD_ACTION" "$FRONTEND_BUILD_DIRECTORY"
  else
    as_code_owner "gulp $FRONTEND_BUILD_ACTION --theme='$GULP_BUILD_THEME_NAME'" "$FRONTEND_BUILD_DIRECTORY"
  fi

  if [ -d "pub/static/frontend/" ] && [ "$IS_NFS" -ne 0 ]; then
    chown -R "${APP_USER}:${APP_GROUP}" pub/static/frontend/
  fi
fi

if [ -f "$DIR/install_magento_custom.sh" ]; then
  # shellcheck source=./install_magento_custom.sh
  source "$DIR/install_magento_custom.sh"
fi
