## How to set the pipeline for backwards compatibility

```bash
fly -t ud set-pipeline \
    -c ~/workspace/pxf-protocol-extension/concourse/pipelines/pxf-protocol-extension_pipeline.yml \
    -l ~/workspace/gp-continuous-integration/secrets/gpdb-6X_STABLE-release-secrets.prod.yml \
    -l ~/workspace/gp-continuous-integration/secrets/gpdb_common-ci-secrets.yml \
    -v pxf-protocol-extension-git-branch=6X_STABLE_pipeline -v pxf-protocol-extension-git-remote=https://github.com/greenplum-db/pxf-protocol-extension \
    -v pxf-git-branch=fix_pgregress_external_table -v pxf-git-remote=https://github.com/greenplum-db/pxf \
    -v folder-prefix=prod/gpdb_branch -v gpdb-branch=6X_STABLE \
    -p pxf-protocol-extension
```
