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

COPY requirements.txt .
RUN pip install --extra-index-url https://download.pytorch.org/whl/cpu -r requirements.txt

# Bake the model into the image so containers start without network access.
ARG MODEL_ID=microsoft/Florence-2-base
ARG MODEL_REVISION=5ca5edf5bd017b9919c05d08aebef5e4c7ac3bac
ENV MODEL_ID=${MODEL_ID} \
    MODEL_REVISION=${MODEL_REVISION}
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('${MODEL_ID}', revision='${MODEL_REVISION}')"

COPY main.py .

RUN useradd --uid 1000 --create-home clippy && \
    mkdir -p "${HF_HOME}/modules" && chown -R clippy:clippy "${HF_HOME}/modules"
USER clippy

ENV HOST=0.0.0.0 \
    PORT=3001 \
    HF_HUB_OFFLINE=1
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:3001/up', timeout=4).status == 200 else 1)"

CMD ["python", "main.py"]
