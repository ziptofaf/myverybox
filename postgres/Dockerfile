# syntax=docker/dockerfile:1

# PostgreSQL 18 with pgvector (semantic search over image embeddings).
# The -trixie variant matters: same Debian/glibc as the official postgres:18
# image, so existing databases keep their text collation (indexes stay valid).
FROM docker.io/pgvector/pgvector:pg18-trixie

# Pick up Debian security fixes released since the base image was built.
RUN apt-get update -qq && apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives
