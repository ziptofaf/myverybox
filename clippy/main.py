from PIL import Image, UnidentifiedImageError
from transformers import AutoProcessor, Florence2ForConditionalGeneration
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
import torch
import io
import os

# Transformers-native Florence-2 checkpoint: no trust_remote_code, so nothing
# from the model repository is ever executed. Pinned to an exact revision.
MODEL_ID = os.environ.get("MODEL_ID", "florence-community/Florence-2-base")
MODEL_REVISION = os.environ.get("MODEL_REVISION", "00921df66db728a9ceb750f5eca43e5c203a2051")
TASK = os.environ.get("TASK", "<MORE_DETAILED_CAPTION>")  # or "<CAPTION>" / "<DETAILED_CAPTION>"
HOST = os.environ.get("HOST", "localhost")
PORT = int(os.environ.get("PORT", "3001"))
MAX_UPLOAD_BYTES = int(os.environ.get("MAX_UPLOAD_BYTES", str(100 * 1024 * 1024)))
# Refuse absurdly large images instead of letting Pillow allocate for them.
Image.MAX_IMAGE_PIXELS = int(os.environ.get("MAX_IMAGE_PIXELS", str(100_000_000)))


def load_model():
    print(f"Loading {MODEL_ID}@{MODEL_REVISION}...", flush=True)
    processor = AutoProcessor.from_pretrained(MODEL_ID, revision=MODEL_REVISION)
    model = Florence2ForConditionalGeneration.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, dtype=torch.float32
    ).eval()
    print("Model loaded.", flush=True)
    return processor, model


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


def run():
    processor, model = load_model()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if urlparse(self.path).path == "/up":
                return self.respond(200, "ok")
            self.respond(404, "Not found")

        # POST /  - image bytes in the request body (used by the Rails app)
        def do_POST(self):
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0:
                return self.respond(400, "Missing image in request body")
            if length > MAX_UPLOAD_BYTES:
                return self.respond(413, "Image too large")
            self.describe_bytes(self.rfile.read(length))

        def describe_bytes(self, content: bytes):
            try:
                image = Image.open(io.BytesIO(content)).convert("RGB")
                self.respond(200, describe(processor, model, image))
            except (UnidentifiedImageError, Image.DecompressionBombError):
                self.respond(400, "Invalid image file")
            except Exception as e:
                self.respond(500, f"Error: {e}")

        def respond(self, status: int, body: str):
            payload = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            try:
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def log_message(self, format, *args):
            print(f"{self.address_string()} - {format % args}", flush=True)

    httpd = HTTPServer((HOST, PORT), Handler)
    print(f"Server running on http://{HOST}:{PORT}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    run()
