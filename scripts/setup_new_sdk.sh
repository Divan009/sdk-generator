#!/usr/bin/env bash

echo "SDK ID (this will be used to create a directory under config/clients/{SDK_ID} and the resulting client will be under clients/{SDK_ID}):"
read -r SDK_ID

CLIENTS_GENERATOR_DIR="${PWD}"
CONFIG_PATH="${CLIENTS_GENERATOR_DIR}/config/clients/${SDK_ID:?}"
SDK_OUTPUT_PATH="${CLIENTS_GENERATOR_DIR}/clients/${SDK_ID}"
appLongName="OpenFGA"
apiDocsUrl="https://openfga.dev/api"

if [ -d "${CONFIG_PATH}" ]; then
  echo "Config Path: ${CONFIG_PATH} already exists. Clear it or choose a different SDK ID"
  exit 1;
fi

if [ -d "${SDK_OUTPUT_PATH}" ]; then
  echo "SDK Output Path: ${SDK_OUTPUT_PATH} already exists. Clear it or choose a different SDK ID"
  exit 1;
fi

echo "Generator (must be a valid generator from https://github.com/OpenAPITools/openapi-generator/blob/master/docs/generators.md):"
read -r GENERATOR

printf "Chosen options:\n- SDK_ID: %s\n- GENERATOR: %s\n\n" "${SDK_ID}" "${GENERATOR:?}"

echo "Task 1: Create config directory at $CONFIG_PATH"

mkdir -p "${CONFIG_PATH}"

printf "Task 1.1: Initialize files"
echo "${GENERATOR}" > "${CONFIG_PATH}/generator.txt"
touch "${CONFIG_PATH}/CHANGELOG.md"
CONFIG_OVERRIDES=$(cat <<EOF
{
  "gitRepoId": "${SDK_ID}-sdk",
  "packageName": "CHANGE_ME",
  "packageVersion": "0.0.1",
  "packageDescription": "${SDK_ID} SDK for ${appLongName}",
  "packageDetailedDescription": "This is an autogenerated ${SDK_ID} SDK for ${appLongName}. It provides a wrapper around the [${appLongName} API definition](${apiDocsUrl}).",
  "files": {}
}
EOF
)
echo "$CONFIG_OVERRIDES" > "${CONFIG_PATH}/config.overrides.json"
touch "${CONFIG_PATH}/.openapi-generator-ignore"
mkdir -p "${CONFIG_PATH}/template/.github/workflows/"
touch "${CONFIG_PATH}/template/.github/workflows/tests.yml"
touch "${CONFIG_PATH}/template/README_installation.mustache"
touch "${CONFIG_PATH}/template/README_initializing.mustache"
touch "${CONFIG_PATH}/template/README_calling_api.mustache"
touch "${CONFIG_PATH}/template/README_api_endpoints.mustache"
touch "${CONFIG_PATH}/template/README_models.mustache"
touch "${CONFIG_PATH}/template/README_license_disclaimer.mustache"
touch "${CONFIG_PATH}/template/README_custom_badges.mustache"
touch "${CONFIG_PATH}/template/gitignore_custom.mustache"

echo " - Done"
printf "Task 1: Done\n\n"

echo "Task 2: Clone template to a temporary directory"
TEMPLATE_SOURCE_REPO="https://github.com/OpenAPITools/openapi-generator"
TEMPLATE_SOURCE_BRANCH=master
TEMPLATE_SOURCE_PATH="modules/openapi-generator/src/main/resources/${GENERATOR}"

printf "Task 2.1: Create temporary directory"
tmpdir=$(mktemp -d)
cd "${tmpdir:?}" || exit
echo " - Done. Temporary directory created at $tmpdir"
printf "Task 2.2: Run git init"
# shellcheck disable=SC2091
$(git init > /dev/null 2>&1) && echo " - Done"
git remote add origin $TEMPLATE_SOURCE_REPO
FETCH_CMD="git fetch -u --depth 1 origin $TEMPLATE_SOURCE_BRANCH:refs/heads/$TEMPLATE_SOURCE_BRANCH "
CLONE_CMD="git checkout $TEMPLATE_SOURCE_BRANCH -- $TEMPLATE_SOURCE_PATH"
printf "Task 2.3: Run fetch command: %s" "$FETCH_CMD"
# shellcheck disable=SC2091
$($FETCH_CMD > /dev/null 2>&1) && echo " - Done"
printf "Task 2.4: Run clone command: %s" "$CLONE_CMD"
# shellcheck disable=SC2091
$($CLONE_CMD > /dev/null 2>&1) && echo " - Done"
printf "Task 2: Done\n\n"

COMMIT_HASH="$(git log -1 --format=format:"%H" origin/$TEMPLATE_SOURCE_BRANCH)"
TEMPLATE_SOURCE_DATA=$(cat <<EOF
{
  "repo": "$TEMPLATE_SOURCE_REPO",
  "branch": "$TEMPLATE_SOURCE_BRANCH",
  "commit": "${COMMIT_HASH:?}",
  "url": "$TEMPLATE_SOURCE_REPO/tree/$TEMPLATE_SOURCE_BRANCH/$TEMPLATE_SOURCE_PATH",
  "docs": "${TEMPLATE_SOURCE_REPO}/blob/$TEMPLATE_SOURCE_BRANCH/docs/generators/${GENERATOR}.md"
}
EOF
)
echo "$TEMPLATE_SOURCE_DATA" > "${CONFIG_PATH}/template-source.json"

echo "Task 3: Copy template to config directory"
COPY_CMD="cp -r "$TEMPLATE_SOURCE_PATH/" "${CONFIG_PATH}/template""
printf "Task 3.1: Run copy command: %s" "$COPY_CMD"
# shellcheck disable=SC2091
$($COPY_CMD > /dev/null 2>&1) && echo " - Done"
printf "Task 3: Done\n\n"

echo "Task 4: Add sample commands to makefile"
printf "Task 4.1: Add %s build command" "$SDK_ID"
BUILD_CLIENT_SNIPPET=$(cat <<EOF

.PHONY: build-client-${SDK_ID}
build-client-${SDK_ID}:
	make build-client sdk_language=${SDK_ID} tmpdir=\${TMP_DIR}
	# ... any other custom build steps ...
EOF
)

echo "$BUILD_CLIENT_SNIPPET" >> "$CLIENTS_GENERATOR_DIR/Makefile"
echo " - Done"
printf "Task 4.2: Add %s test command" "$SDK_ID"
BUILD_CLIENT_SNIPPET=$(cat <<EOF

.PHONY: test-client-${SDK_ID}
test-client-${SDK_ID}: build-client-${SDK_ID}
	# ... any custom test code ...
EOF
)

echo "$BUILD_CLIENT_SNIPPET" >> "$CLIENTS_GENERATOR_DIR/Makefile"
echo " - Done"

echo "Task 4: Done"

echo "Use ${TEMPLATE_SOURCE_REPO}/blob/$TEMPLATE_SOURCE_BRANCH/docs/generators/${GENERATOR}.md to configure the SDK generator in ${CONFIG_PATH}/config.overrides.json"
echo "Then run: make build-client-${SDK_ID}"
