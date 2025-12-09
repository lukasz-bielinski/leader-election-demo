# Build stage
FROM golang:1.24-alpine AS builder
WORKDIR /app

# Install git (needed for some Go modules)
RUN apk add --no-cache git

# Copy go mod files first for better layer caching
COPY go.mod go.sum ./

# Download dependencies with cache mount (faster rebuilds)
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy source code
COPY *.go ./

# Build with cache mount for Go build cache
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -ldflags="-w -s" -o /leader-election .

# Runtime - alpine for shell access (demo)
FROM alpine:3.20
COPY --from=builder /leader-election /leader-election
ENTRYPOINT ["/leader-election"]
