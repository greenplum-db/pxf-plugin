## How to set the pipeline for backwards compatibility

```bash
fly -t ud set-pipeline \
    -c ~/workspace/pxf-protocol-extension/concourse/pipelines/pxf-protocol-extension_pipeline.yml \
    -l ~/workspace/gp-continuous-integration/secrets/gpdb-6X_STABLE-release-secrets.prod.yml \
    -l ~/workspace/gp-continuous-integration/secrets/gpdb_common-ci-secrets.yml \
    -v pxf-protocol-extension-git-branch=6X_STABLE_pipeline -v pxf-protocol-extension-git-remote=https://github.com/greenplum-db/pxf-protocol-extension \
    -p pxf-protocol-extension
```
