from PIL import Image, UnidentifiedImageError
from transformers import AutoModel, AutoProcessor, Florence2ForConditionalGeneration
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import threading
import json
import torch
import io
import os

# Transformers-native Florence-2 checkpoint: no trust_remote_code, so nothing
# from the model repository is ever executed. Pinned to an exact revision.
MODEL_ID = os.environ.get("MODEL_ID", "florence-community/Florence-2-base")
MODEL_REVISION = os.environ.get("MODEL_REVISION", "00921df66db728a9ceb750f5eca43e5c203a2051")
TASK = os.environ.get("TASK", "<MORE_DETAILED_CAPTION>")  # or "<CAPTION>" / "<DETAILED_CAPTION>"

# SigLIP 2: embeds images and text into the same vector space (semantic search).
EMBEDDING_MODEL_ID = os.environ.get("EMBEDDING_MODEL_ID", "google/siglip2-base-patch16-256")
EMBEDDING_MODEL_REVISION = os.environ.get("EMBEDDING_MODEL_REVISION", "3f9f96cb90da5dbc758b01813f2f6f1aee24c1ab")
# SigLIP's text encoder was trained on lowercased text padded to 64 tokens.
EMBEDDING_TEXT_LENGTH = 64

HOST = os.environ.get("HOST", "localhost")
PORT = int(os.environ.get("PORT", "3001"))
MAX_UPLOAD_BYTES = int(os.environ.get("MAX_UPLOAD_BYTES", str(100 * 1024 * 1024)))
MAX_TEXT_BYTES = 4096
# Refuse absurdly large images instead of letting Pillow allocate for them.
Image.MAX_IMAGE_PIXELS = int(os.environ.get("MAX_IMAGE_PIXELS", str(100_000_000)))
# At most this many images are decoded/processed at once; further image
# requests wait *before* decoding, so a burst of uploads can't pile up memory.
MAX_CONCURRENT_IMAGES = int(os.environ.get("MAX_CONCURRENT_IMAGES", "4"))


def load_models():
    print(f"Loading {MODEL_ID}@{MODEL_REVISION}...", flush=True)
    processor = AutoProcessor.from_pretrained(MODEL_ID, revision=MODEL_REVISION)
    model = Florence2ForConditionalGeneration.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, dtype=torch.float32
    ).eval()

    print(f"Loading {EMBEDDING_MODEL_ID}@{EMBEDDING_MODEL_REVISION}...", flush=True)
    emb_processor = AutoProcessor.from_pretrained(EMBEDDING_MODEL_ID, revision=EMBEDDING_MODEL_REVISION)
    emb_model = AutoModel.from_pretrained(
        EMBEDDING_MODEL_ID, revision=EMBEDDING_MODEL_REVISION, dtype=torch.float32
    ).eval()
    print("Models loaded.", flush=True)
    return processor, model, emb_processor, emb_model


def describe(processor, model, image: Image.Image) -> str:
    inputs = processor(text=TASK, images=image, return_tensors="pt")
    with torch.no_grad():
        generated_ids = model.generate(
            **inputs,
            max_new_tokens=256,
            num_beams=3,
            do_sample=False,
        )
    raw = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
    parsed = processor.post_process_generation(
        raw, task=TASK, image_size=(image.width, image.height)
    )
    return parsed[TASK].strip()


def _normalized(features) -> list:
    # get_*_features may return a tensor or a model output, depending on version
    if not isinstance(features, torch.Tensor):
        features = features.pooler_output
    features = torch.nn.functional.normalize(features, dim=-1)
    return [round(float(x), 6) for x in features[0]]


def embed_image(processor, model, image: Image.Image) -> list:
    inputs = processor(images=[image], return_tensors="pt")
    with torch.no_grad():
        return _normalized(model.get_image_features(**inputs))


def embed_text(processor, model, text: str) -> list:
    inputs = processor(
        text=[text.lower()],
        padding="max_length",
        max_length=EMBEDDING_TEXT_LENGTH,
        truncation=True,
        return_tensors="pt",
    )
    with torch.no_grad():
        return _normalized(model.get_text_features(**inputs))


def run():
    processor, model, emb_processor, emb_model = load_models()
    # Requests are served concurrently (a search must not wait behind a
    # multi-second description); each model is used by one request at a time.
    describe_lock = threading.Lock()
    embed_lock = threading.Lock()
    image_slots = threading.BoundedSemaphore(MAX_CONCURRENT_IMAGES)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if urlparse(self.path).path == "/up":
                return self.respond(200, "ok")
            self.respond(404, "Not found")

        def do_POST(self):
            path = urlparse(self.path).path
            if path == "/":                 # image bytes -> text description
                self.handle_image(lambda image: self.locked(describe_lock, describe, processor, model, image))
            elif path == "/embed/image":    # image bytes -> embedding (JSON)
                self.handle_image(lambda image: self.embedding(
                    self.locked(embed_lock, embed_image, emb_processor, emb_model, image)))
            elif path == "/embed/text":     # UTF-8 text -> embedding (JSON)
                self.handle_text()
            else:
                self.respond(404, "Not found")

        def read_body(self, limit: int):
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0:
                self.respond(400, "Missing request body")
                return None
            if length > limit:
                self.respond(413, "Request body too large")
                return None
            return self.rfile.read(length)

        def handle_image(self, action):
            with image_slots:
                self.process_image(action)

        def process_image(self, action):
            content = self.read_body(MAX_UPLOAD_BYTES)
            if content is None:
                return
            try:
                image = Image.open(io.BytesIO(content)).convert("RGB")
            except (UnidentifiedImageError, Image.DecompressionBombError):
                return self.respond(400, "Invalid image file")
            except Exception as e:
                return self.respond(400, f"Invalid image file: {e}")
            try:
                result = action(image)
                if isinstance(result, tuple):
                    self.respond(*result)
                else:
                    self.respond(200, result)
            except Exception as e:
                self.respond(500, f"Error: {e}")

        def handle_text(self):
            content = self.read_body(MAX_TEXT_BYTES)
            if content is None:
                return
            text = content.decode("utf-8", errors="replace").strip()
            if not text:
                return self.respond(400, "Empty text")
            try:
                self.respond(*self.embedding(self.locked(embed_lock, embed_text, emb_processor, emb_model, text)))
            except Exception as e:
                self.respond(500, f"Error: {e}")

        @staticmethod
        def locked(lock, fn, *args):
            with lock:
                return fn(*args)

        @staticmethod
        def embedding(vector):
            body = json.dumps({"model": EMBEDDING_MODEL_ID, "dimensions": len(vector), "embedding": vector})
            return 200, body, "application/json"

        def respond(self, status: int, body: str, content_type: str = "text/plain; charset=utf-8"):
            payload = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            try:
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def log_message(self, format, *args):
            print(f"{self.address_string()} - {format % args}", flush=True)

    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    httpd.daemon_threads = True
    print(f"Server running on http://{HOST}:{PORT}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    run()
