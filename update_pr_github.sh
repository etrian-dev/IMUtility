#!/bin/bash

set -e

# To be adjusted to local setup
ECLAIR_PATH=${ECLAIR_PATH:-/opt/bugseng/eclair/bin/}
eclair_report="${ECLAIR_PATH}eclair_report"

usage() {
    echo "Usage: $0 RESULTS_ROOT JOB_ID JOB_HEADLINE COMMIT_ID PR_BASE_SHA" >&2
    exit 2
}

[[ $# -eq 5 ]] || usage

results_root=$1
current_job_id=$2
job_headline=$3
commit_id=$4
pr_base_sha=$5

commits_dir="${results_root}/commits"

pr_dir="${results_root}/pr"
pr_current_dir="${pr_dir}/${current_job_id}"
pr_db="${pr_current_dir}/PROJECT.ecd"
pr_index="${pr_current_dir}/index.html"
pr_base_db_name="PROJECT_base.ecd"

mkdir -p "${commits_dir}"
mkdir -p "${pr_dir}"

# The group where eclair_report runs must be in this file's group
chmod -R g+w "${pr_db}"

base_dir="${commits_dir}/${pr_base_sha}"
base_job_id=
[[ ! -d "${base_dir}" ]] || base_job_id=$(basename "$(realpath "${base_dir}")")

# Generate a file index.html for PRs
generate_index_pr() {

    local head_dir
    local base_dir

    # HTML elements
    local counts_msg
    local base_link

    head_dir=$1
    base_dir=$(basename "$(realpath "${head_dir}/prev")")

    if [[ -d ${base_dir} ]]; then
        counts_msg="<p>Fixed reports: ${fixed_reports} (<a href=\"${pr_base_db_name}\">previous database</a>)</p>
                    <p>New reports: ${new_reports} (<a href=\"PROJECT.ecd\">current database</a>)</p>"
        base_link="<a href=\"../../${base_dir}/index.html\">Previous job</a>, "
    fi

    pr_db_msg="<a href=\"PROJECT.ecd\">current database</a>)</p>"

    cat <<EOF
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <link href="/rsrc/overall.css" rel="stylesheet" type="text/css">
    <title>${job_headline}: ECLAIR job #${current_job_id}</title>
    </head>
    <body>

    <div class="header">
        <a href="http://bugseng.com/eclair" target="_blank">
            <img src="/rsrc/eclair.png" alt="ECLAIR">
        </a>
        <span>${job_headline}: ECLAIR job #${current_job_id}</span>
    </div>
    ${pr_db_msg}
    ${counts_msg}
    <br>
    <p>
        ${base_link}<a href="../..">Jobs</a>
    </p>
    <div class="footer"><div>
        <a href="http://bugseng.com" target="_blank"><img src="/rsrc/bugseng.png" alt="BUGSENG">
            <span class="tagline">software verification done right.</span>
        </a>
        <br>
        <span class="copyright">
            The design of this web resource is Copyright © 2010-2022 BUGSENG srl. All rights reserved worldwide.
        </span>
    </div></div>

    </body>
    </html>
EOF
}

if [[ -n "${base_job_id}" ]]; then

    # For PRs, the base db is copied in the current PR's subdir, to avoid altering it
    cp "${base_db}" "${pr_current_dir}/${pr_base_db_name}"
    base_db="${pr_current_dir}/${pr_base_db_name}"

    # Tag previous and current databases
    ${eclair_report} -setq=diff_tag_domain1,next -setq=diff_tag_domain2,prev \
        -tag_diff="'${base_db}','${pr_db}'"

    # Count reports
    fixed_reports=$(${eclair_report} -db="${base_db}" -sel_tag_glob=diff_next,next,missing '-print="",reports_count()')
    new_reports=$(${eclair_report} -db="${pr_db}" -sel_tag_glob=diff_prev,prev,missing '-print="",reports_count()')

    # Generate badge for the current run
    anybadge -o --label="ECLAIR" --value="fixed ${fixed_reports} | new ${new_reports}" --file="${pr_dir}/badge.svg"

    # Add link to base commit of the current run
    ln -s "../../${base_job_id}" "${pr_db}/base"

    # Generate index for the PR
    generate_index_pr "${pr_current_dir}" >"${pr_index}"
else
    # No base commit analysis found
    # TODO: what to do?
    new_reports=$(${eclair_report} -db="${pr_db}" '-print="",reports_count()')
    anybadge -o --label="ECLAIR ${current_job_id}" --value="reports: ${new_reports}" --file="${pr_dir}/badge.svg"

    # Generate index for the current job
    generate_index "${pr_dir}" >"${pr_index}"
fi

# Update last symlink
ln -sfn "${current_job_id}" "${results_root}/last"

# Add a link relating commit id to last build done for it
ln -sfn "../${current_job_id}" "${commits_dir}/${commit_id}"

# Generate summary and print it (Github-specific)
{
    echo "# ECLAIR analysis summary:"
    printf "Fixed reports: %d\n" "${fixed_reports}"
    printf "New reports: %d\n" "${new_reports}"
    echo "[Browse analysis](https://${ECLAIR_REPORT_HOST}/fs${pr_index})"
} >>"${pr_dir}/summary.txt"
cat "${pr_dir}/summary.txt"
