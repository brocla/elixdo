$sha = git rev-parse --short HEAD
fly deploy --build-arg "GIT_SHA=$sha"
