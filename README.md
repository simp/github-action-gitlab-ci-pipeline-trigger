# github-action-gitlab-ci-pipeline-trigger
Live Dangerously and TRIGGER GITLAB CI FROM GITHUB ACTIONS _(seriously: see the [security implications](#warning-security-implications-warning))_

[![Verify Action](https://github.com/simp/github-action-gitlab-ci-pipeline-trigger/workflows/Verify%20Action/badge.svg)](https://github.com/simp/github-action-gitlab-ci-pipeline-trigger/actions?query=workflow%3A%22Verify+Action%22)
[![tag badge](https://img.shields.io/github/v/tag/simp/github-action-gitlab-ci-pipeline-trigger)](https://github.com/simp/github-action-gitlab-ci-pipeline-trigger/tags)
[![license badge](https://img.shields.io/github/license/simp/github-action-gitlab-ci-pipeline-trigger)](./LICENSE)


<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Usage](#usage)
* [Reference](#reference)
  * [Action inputs](#action-inputs)
  * [Action outputs](#action-outputs)
  * [:warning: Security implications :warning:](#warning-security-implications-warning)
* [Contributing](#contributing)
* [Feedback & Questions](#feedback--questions)
* [License](#license)

<!-- vim-markdown-toc -->

## Description

A [Github action] to push a GitHub commit to GitLab in order to trigger a
GitLab CI pipeline.


* Automatically cancels existing GitLab CI pipelines with the same branch name
  before pushing the new commit
  * Exception: It will leave alone an existing pipeline for the same commit hash
* Unlike the GitLab CI external CI/CD webhook, this enables PRs from forked
  repositories to trigger GitLab CI pipelines
  * (**IMPORTANT:** see [SECURITY IMPLICATIONS](#warning-security-implications-warning))


## Usage

To safely execute during a `pull_request_target` event, try something like the
following (using a previous **`contributor-permissions`** job to determine if
the Pull Request submitter is trusted):

```yaml
  trigger-when-user-has-repo-permissions:
    name: 'Trigger CI [trusted users only]'
    needs: [ glci-syntax, contributor-permissions ]
    runs-on: ubuntu-18.04
    steps:
      - uses: actions/checkout@v2
        if: needs.contributor-permissions.outputs.permitted == 'true'
        with:
          clean: true
          fetch-depth: 0  # Need full checkout to push to gitlab mirror
          repository: ${{ github.event.pull_request.head.repo.full_name }}
          ref: ${{ github.event.pull_request.head.ref }}

      - name: Trigger CI when user has Repo Permissions
        if: needs.contributor-permissions.outputs.permitted == 'true'
        uses: simp/github-action-gitlab-ci-pipeline-trigger@v1
        with:
          git_branch: ${{ github.event.pull_request.head.ref }}
          git_hashref:  ${{ github.event.pull_request.head.sha }}
          gitlab_api_private_token: ${{ secrets.GITLAB_API_PRIVATE_TOKEN }}
          gitlab_group: ${{ github.event.organization.login }}
          github_repository: ${{ github.repository }}
          github_repository_owner: ${{ github.repository_owner }}

      - name: When user does NOT have Repo Permissions
        if: needs.contributor-permissions.outputs.permitted == 'false'
        continue-on-error: true
        run: |
          echo "Ending gracefully; Contributor $GITHUB_ACTOR does not have permission to trigger CI"
          false

```


## Reference

### Action inputs

<table>
  <thead>
    <tr>
      <th>Input</th>
      <th>Required</th>
      <th>Description</th>
    </tr>
  </thead>

  <tr>
    <td><strong><code>git_branch</code></strong></td>
    <td>Yes</td>
    <td>Branch name to use when pushing to gitlab/GLCI</td>
  </tr>

  <tr>
    <td><strong><code>git_hashref</code></strong></td>
    <td>Yes</td>
    <td>Hashref of git commit to push to GLCI</td>
  </tr>

  <tr>
    <td><strong><code>gitlab_api_private_token</code></strong></td>
    <td>Yes</td>
    <td>GitLab API private token (should have `api` scope)</td>
  </tr>

  <tr>
    <td><strong><code>gitlab_group</code></strong></td>
    <td>Yes</td>
    <td>Gitlab Group to push to<br /><em>Default:</em> <code>${{ github.event.organization.login }}</code></td>
  </tr>

  <tr>
    <td><strong><code>gitlab_server_url</code></strong></td>
    <td>Yes</td>
    <td>Specify a GitLab server other than gitlab.com<br /><em>Default:</em> <code>https://gitlab.com</code></td>
  </tr>

  <tr>
    <td><strong><code>gitlab_api_url</code></strong></td>
    <td>Yes</td>
    <td>Specify a GitLab API other than gitlab.com<br /><em>Default:</em> <code>https://gitlab.com/api/v4</code></td>
  </tr>

  <tr>
    <td><strong><code>github_repository</code></strong></td>
    <td>Yes</td>
    <td>TODO<br /><em>Default:</em> <code>${{ github.repository }}</code></td>
  </tr>

  <tr>
    <td><strong><code>github_repository_owner</code></strong></td>
    <td>Yes</td>
    <td>TODO<br /><em>Default:</em> <code>${{ github.repository_owner }}</code></td>
  </tr>
</table>

### Action outputs

None

### :warning: Security implications :warning:

There are very good reasons that GitLab's native GitHub integration doesn't
permit pull requests from forks to trigger GitLab CI pipelines.  Make **VERY**
sure in your workflow that you can trust the PR submitter before permitting
this action to trigger on PRs.

## Contributing

This is an open source project open to anyone. This project welcomes contributions and suggestions!

## Feedback & Questions

If you discover an issue, please report it on our Jira at
https://simp-project.atlassian.net/

## License

Apache 2.0, See [LICENSE](https://github.com/simp/github-action-gitlab-ci-pipeline-trigger/blob/main/LICENSE) for more information.



[GitHub action]: https://github.com/features/actions
