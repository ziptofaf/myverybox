# syntax=docker/dockerfile:1

# Image description service (Florence-2 on CPU), used by the Rails app to fill
# in FileUpload#description.
FROM docker.io/library/python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/opt/huggingface

WORKDIR /app

# Pick up Debian security fixes released since the base image was built.
RUN apt-get update -qq && apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY requirements.txt .
# torch is pinned as "+cpu", which exists only on the PyTorch CPU index, so the
# multi-GB CUDA builds from PyPI can never be picked.
RUN pip install --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple -r requirements.txt

# Bake the model into the image so containers start without network access.
ARG MODEL_ID=florence-community/Florence-2-base
ARG MODEL_REVISION=00921df66db728a9ceb750f5eca43e5c203a2051
ENV MODEL_ID=${MODEL_ID} \
    MODEL_REVISION=${MODEL_REVISION}
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('${MODEL_ID}', revision='${MODEL_REVISION}')" && \
    chmod -R a+rX "${HF_HOME}"

COPY main.py .

RUN useradd --uid 1000 --create-home clippy
USER clippy

ENV HOST=0.0.0.0 \
    PORT=3001 \
    HF_HUB_OFFLINE=1
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:3001/up', timeout=4).status == 200 else 1)"

CMD ["python", "main.py"]
