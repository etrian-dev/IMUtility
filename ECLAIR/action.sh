#!/bin/sh

set -e

cd "$(dirname "$0")"

usage() {
    echo "Usage: $0 ANALYSIS_OUTPUT_PATH PR_BASE_COMMIT_ID PR_HEADLINE" >&2
    exit 2
}

[ $# -eq 3 ] || usage

ANALYSIS_OUTPUT_PATH="$1"
PR_BASE_COMMIT_ID="$2"
PR_HEADLINE="$3"

# Set variables
CI="github"

#ECLAIR_REPORT_USER="github"
ECLAIR_REPORT_HOST='eclairit.com:3787'
ECLAIR_REPORT_HOST_SCP=
ECLAIR_REPORT_HOST_SH='sh -c'

PROJECT_PATH=${GITHUB_REPOSITORY}
JOB_ID=${GITHUB_RUN_NUMBER}

ARTIFACTS_ROOT='/home/github/public'
PROJECT_ARTIFACTS_PATH=${ARTIFACTS_ROOT}/${PROJECT_PATH}'.ecdf'
# Analysis link on eclair report host, for the summary
ANALYSIS_HOST='https://'${ECLAIR_REPORT_HOST}'/fs'

# Extract PR number from "refs/pull/<prnum>/merge"
PR_ID=$(echo "${GITHUB_REF}" | cut -d / -f 3)
# Extract the branch name from "refs/heads/<branch>"
BRANCH=$(echo "${GITHUB_REF}" | cut -d / -f 3)
# Badge label name
BADGE_LABEL="ECLAIR ${BRANCH} #${JOB_ID}"

ECD_DESTINATION=${ECLAIR_REPORT_HOST_SCP}${PROJECT_ARTIFACTS_PATH}/${BRANCH}/${JOB_ID}/
if [ "${IS_PULL_REQUEST}" = 'true' ]; then
    # create a (pr) directory for the analysis results
    ${ECLAIR_REPORT_HOST_SH} "mkdir -p ${PROJECT_ARTIFACTS_PATH}/pr/${JOB_ID}/"
    ECD_DESTINATION=${ECLAIR_REPORT_HOST_SCP}${PROJECT_ARTIFACTS_PATH}/pr/${JOB_ID}/
else
    # create a directory for the analysis results
    ${ECLAIR_REPORT_HOST_SH} "mkdir -p ${PROJECT_ARTIFACTS_PATH}/${BRANCH}/${JOB_ID}/"
fi
# Transfer the database to eclair_report_host
scp "${ANALYSIS_OUTPUT_PATH}/PROJECT.ecd" "${ECD_DESTINATION}"

# Send the script to tag databases, create symlinks and badges
scp update_push.sh update_pull_request.sh "${ECLAIR_REPORT_HOST_SCP}${PROJECT_ARTIFACTS_PATH}"
# Execute it on that host
# NOTE: Common arguments between scripts are on the first line
{
    if [ "${IS_PULL_REQUEST}" = 'true' ]; then
        ${ECLAIR_REPORT_HOST_SH} "ANALYSIS_HOST=${ANALYSIS_HOST} \
${PROJECT_ARTIFACTS_PATH}/update_pr_github.sh \
'${CI}' '${PROJECT_ARTIFACTS_PATH}' '${JOB_ID}' '${GITHUB_REPOSITORY}' '${GITHUB_SHA}' \
'${PR_ID}' '${PR_BASE_COMMIT_ID}' '${PR_HEADLINE}'"
    else
        ${ECLAIR_REPORT_HOST_SH} "ANALYSIS_HOST=${ANALYSIS_HOST} \
${PROJECT_ARTIFACTS_PATH}/update.sh \
'${CI}' '${PROJECT_ARTIFACTS_PATH}' '${JOB_ID}' '${GITHUB_REPOSITORY}' '${GITHUB_SHA}' \
'${BRANCH}' '${BADGE_LABEL}'"
    fi
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
