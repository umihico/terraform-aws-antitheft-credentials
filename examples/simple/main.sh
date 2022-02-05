#!/bin/bash
set -euo pipefail

################################################################################
###                           CONFIGURATION AREA                             ###
################################################################################
BASTION_PROFILE="bastion"
MFA_NAME="umihico"
DEFAULT_AWS_ACCOUNT_ID="123456789012"
################################################################################
###                        END OF CONFIGURATION AREA                         ###
################################################################################


export PAGER=""
DEFAULT_AWS_ACCOUNT_ID="${EXTERNAL_DEFAULT_AWS_ACCOUNT_ID:-$DEFAULT_AWS_ACCOUNT_ID}" # for testing
BASTION_AWS_ACCOUNT_INFO=$(aws sts get-caller-identity --profile $BASTION_PROFILE)
BASTION_AWS_ACCOUNT_ID=$(echo $BASTION_AWS_ACCOUNT_INFO | jq -r ".Account")
BASTION_USERNAME=$(echo $BASTION_AWS_ACCOUNT_INFO | jq -r '.Arn | split("/")[1]')
MFA_SERIAL_NUMBER="arn:aws:iam::${BASTION_AWS_ACCOUNT_ID}:mfa/${MFA_NAME}"
POLICY_CHANGER_ROLE_ARN="arn:aws:iam::${DEFAULT_AWS_ACCOUNT_ID}:role/BastionUpdatePolicyRole"
ROLE_SESSION_NAME="${BASTION_USERNAME}-$(command date +%s)"
DYNAMODB_TABLE_NAME="bastion-ip-address-table"
echo "Enter MFA code for ${MFA_SERIAL_NUMBER}:"
read TOKEN_CODE

export AWS_PROFILE=$BASTION_PROFILE
export AWS_DEFAULT_OUTPUT=json

CRED=$(aws sts assume-role \
  --role-session-name $ROLE_SESSION_NAME \
  --role-arn $POLICY_CHANGER_ROLE_ARN \
  --serial-number $MFA_SERIAL_NUMBER \
  --token-code $TOKEN_CODE \
  --duration-seconds 900 \
  --query 'Credentials')

export AWS_ACCESS_KEY_ID=$(echo $CRED | jq -r ".AccessKeyId")
export AWS_SECRET_ACCESS_KEY=$(echo $CRED | jq -r ".SecretAccessKey")
export AWS_SESSION_TOKEN=$(echo $CRED | jq -r ".SessionToken")

MY_IP=$(curl -s https://checkip.amazonaws.com)
DYNAMODB_ITEM=$(cat <<-END
{
  "IpAddress": {
    "S": "$MY_IP/32"
  },
  "ExpireAt": {
    "N": "$(($(date +%s) + (60 * 60 * 12)))"
  }
}
END
)

aws dynamodb put-item \
  --table-name $DYNAMODB_TABLE_NAME \
  --item $(echo $DYNAMODB_ITEM | jq -r 'tostring')

ALLOWED_IPS=$(aws dynamodb scan \
  --table-name $DYNAMODB_TABLE_NAME \
  --query "Items[].IpAddress.S" \
  | jq -r 'unique|tostring')

POLICY=$(cat <<-END
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "Bool": {"aws:ViaAWSService": "false"},
        "IpAddress": {
          "aws:SourceIp": $ALLOWED_IPS
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "Bool": {"aws:ViaAWSService": "true"}
      }
    }
  ]
}
END
)

aws iam put-role-policy \
  --role-name BastionUserDefaultRole \
  --policy-name BastionUserDefaultRole_policy \
  --policy-document $(echo $POLICY | jq -r 'tostring')

echo "Your IP '$MY_IP' is allowed."