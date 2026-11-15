FROM alpine:3.20
RUN apk add --no-cache bash git bats make coreutils diffutils \
 && git config --system safe.directory '*' \
 && git config --system user.email test@example.com \
 && git config --system user.name Test \
 && git config --system init.defaultBranch main
WORKDIR /repo
