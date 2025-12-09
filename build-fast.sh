#!/bin/bash
# Fast build with cache
docker buildx build \
  --platform linux/arm64 \
  --cache-from type=registry,ref=lukaszbielinski/leader-election-demo-go:buildcache \
  --cache-to type=registry,ref=lukaszbielinski/leader-election-demo-go:buildcache,mode=max \
  -t lukaszbielinski/leader-election-demo-go:latest \
  --push \
  .
