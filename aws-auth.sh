#!/usr/bin/env bash

# exit immediately after failed command
# pipe exit code evaluates all pipe commands
set -eo pipefail

# aws cli default cache dir
CACHE_DIR=~/.aws/cli/cache

# get or refresh temporary credentials into cache dir
aws sts get-caller-identity > /dev/null

if [ -n "$AWS_PROFILE" ]; then
  # get source profile
  source_profile="$(aws configure get source_profile --profile "$AWS_PROFILE" || echo "")"

  if [ -n "$source_profile" ]; then
    # get role arn
    role_arn="$(aws configure get role_arn --profile "$AWS_PROFILE")"

    # get mfa serial if configured, set cache file accordingly
    mfa_serial="$(aws configure get mfa_serial --profile "$AWS_PROFILE" || echo "")"
    if [ -n "$mfa_serial" ]; then
        cache_file=${CACHE_DIR}/$(echo -n "{\"RoleArn\": \"$role_arn\", \"SerialNumber\": \"$mfa_serial\"}" | openssl dgst -sha1 | cut -d " " -f 2).json
    else
        cache_file=${CACHE_DIR}/$(echo -n "{\"RoleArn\": \"$role_arn\"}" | openssl dgst -sha1 | cut -d " " -f 2).json
    fi

    # get default aws region
    AWS_DEFAULT_REGION=$(aws configure get region --profile "$AWS_PROFILE" ||
                         aws configure get region --profile "$source_profile" ||
                         echo "")

    AWS_ACCESS_KEY_ID="$(jq -r ".Credentials.AccessKeyId" $cache_file)"
    AWS_SECRET_ACCESS_KEY="$(jq -r ".Credentials.SecretAccessKey" $cache_file)"
    AWS_SECURITY_TOKEN="$(jq -r ".Credentials.SessionToken" $cache_file)"
    AWS_SESSION_TOKEN=$AWS_SECURITY_TOKEN
  else
    AWS_DEFAULT_REGION="$(aws configure get region --profile "$AWS_PROFILE" || echo "")"
    AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id --profile "$AWS_PROFILE" || echo "")"
    AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key --profile "$AWS_PROFILE" || echo "")"
  fi
fi

[ -n "$AWS_DEFAULT_REGION" ] && export AWS_DEFAULT_REGION
[ -n "$AWS_ACCESS_KEY_ID" ] && export AWS_ACCESS_KEY_ID
[ -n "$AWS_SECRET_ACCESS_KEY" ] && export AWS_SECRET_ACCESS_KEY
[ -n "$AWS_SECURITY_TOKEN" ] && export AWS_SECURITY_TOKEN
[ -n "$AWS_SESSION_TOKEN" ] && export AWS_SESSION_TOKEN

exec "$@"
