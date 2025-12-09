# Build stage
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o /leader-election .

# Runtime - minimal
FROM scratch
COPY --from=builder /leader-election /leader-election
ENTRYPOINT ["/leader-election"]

