#!/bin/bash -e
# shellcheck disable=SC2016
[ -z "$GIT_BRANCH" ] && { echo '::error ::$GIT_BRANCH cannot be empty!'; exit 88; }
# shellcheck disable=SC2016
[ -z "$GITLAB_GROUP" ] && { echo '::error ::$GITLAB_GROUP cannot be empty!'; exit 88; }
# shellcheck disable=SC2016
[ -z "$GITLAB_API_PRIVATE_TOKEN" ] && { echo '::error ::$GITLAB_API_PRIVATE_TOKEN cannot be empty!'; exit 88; }
GIT_HASHREF="${GIT_HASHREF:-$(git log -1 --pretty='%H')}"
# shellcheck disable=SC2016
[ -z "$GIT_HASHREF" ] && { echo '::error ::$GIT_HASHREF cannot be empty!'; exit 88; }
# shellcheck disable=SC2016
[ -z "$GITHUB_REPOSITORY" ] && { echo '::error ::$GITHUB_REPOSITORY cannot be empty!'; exit 88; }
# shellcheck disable=SC2016
[ -z "$GITHUB_REPOSITORY_OWNER" ] && { echo '::error ::$GITHUB_REPOSITORY_OWNER cannot be empty!'; exit 88; }

GITLAB_SERVER_URL="${GITLAB_SERVER_URL:-https://gitlab.com}"
GITLAB_API_URL="${GITLAB_API_URL:-${GITLAB_SERVER_URL}/api/v4}"
GITXXB_REPO_NAME="${GITHUB_REPOSITORY/$GITHUB_REPOSITORY_OWNER\//}"
GITLAB_PROJECT_ID="${GITLAB_GROUP}%2F${GITXXB_REPO_NAME}"

# --http1.0 avoids an HTTP/2 load balancing issue when run from GA
CURL_CMD=(curl --http1.0 --fail --silent --show-error \
  --header "Authorization: Bearer $GITLAB_API_PRIVATE_TOKEN" \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" \
)


echo "  --- Local target commit: $GIT_HASHREF"

active_pipeline_ids=()
same_sha_pipeline_id=""
jq_same_pipeline_id_query="$(printf '.[] | select(.sha=="%s") | .id' "$GIT_HASHREF")"

# Cancel any active/pending GitLab CI pipelines for the same
# project+branch, UNLESS it's already for this commit
for pipe_status in created waiting_for_resource preparing pending running; do
  pipe_status_url="${GITLAB_API_URL}/projects/${GITLAB_PROJECT_ID}/pipelines?ref=${GIT_BRANCH}&status=${pipe_status}"

  printf "\\n  ---- checking for CI pipelines with status '%s' for project '%s', branch '%s'\\n" \
    "$pipe_status" "$GITLAB_PROJECT_ID" "$GIT_BRANCH"
  curl_response_body="$("${CURL_CMD[@]}" "$pipe_status_url")"

  active_pipelines="$(echo "$curl_response_body" | jq -r '.[] | .id , .web_url')"
  # shellcheck disable=SC2207
  active_pipeline_ids+=($(echo "$active_pipelines" | grep -E '^[0-9]*$'))
  [ -n "$active_pipelines" ] && echo "$active_pipelines" && echo

  if [ -z "$same_sha_pipeline_id" ]; then
    same_sha_pipeline_id="$(echo "$curl_response_body" | jq -r "$jq_same_pipeline_id_query")"
  fi
done

if [ "${#active_pipeline_ids[@]}" -gt 0 ]; then
  printf "\\n  ---- Found %s active pipeline ids:\\n" "${#active_pipeline_ids[@]}"
  echo "${active_pipeline_ids[@]}"
  for pipe_id in "${active_pipeline_ids[@]}"; do
  [ -n "$same_sha_pipeline_id" ] && [ "$pipe_id" == "$same_sha_pipeline_id" ] && continue
    printf "\\n  ------ Cancelling pipeline ID %s...\\n" "$pipe_id"
    "${CURL_CMD[@]}" --request POST "${GITLAB_API_URL}/projects/${GITLAB_PROJECT_ID}/pipelines/${pipe_id}/cancel"
  done
else
  echo No active pipelines found
fi
printf "\\n\\n"

# Short-circuit GLCI trigger if there's already a pipeline for our ref
if [ -n "$same_sha_pipeline_id" ]; then
  msg="No need to push '$GIT_BRANCH' to gitlab; Pipeline for same commit '$GIT_HASHREF' running at:"
  msg_url="https://${GITLAB_SERVER_URL#*://}/${GITLAB_GROUP}/${GITXXB_REPO_NAME}/-/pipelines/${same_sha_pipeline_id}"
  printf "== %s\\n   %s\\n" "$msg" "$msg_url"
  echo "::warning ::$msg $msg_url"
  exit 0
fi

echo "== Pushing $GIT_BRANCH to gitlab"
git remote add gitlab "https://oauth2:${GITLAB_API_PRIVATE_TOKEN}@${GITLAB_SERVER_URL#*://}/${GITLAB_GROUP}/${GITXXB_REPO_NAME}.git"
# Some workflows won't have checked out the branch
git show-ref --verify --quiet "refs/heads/$GIT_BRANCH" || git branch "$GIT_BRANCH" HEAD
git log --color --graph  --abbrev-commit -5 \
  --pretty=format:'%C(red)%h%C(reset) -%C(yellow)%d%Creset %s %Cgreen(%ci) %C(bold blue)<%an>%Creset'
git push gitlab ":${GIT_BRANCH}" -f || : # attempt to un-weird GLCI's `changed` tracking
git push gitlab "${GIT_BRANCH}" -f || exit 99
echo "Pushed branch '${GIT_BRANCH}' to gitlab"
echo "   A new pipeline should be at: https://${GITLAB_SERVER_URL#*://}/${GITLAB_GROUP}/${GITXXB_REPO_NAME}/-/pipelines/"

