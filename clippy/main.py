from PIL import Image, UnidentifiedImageError
from transformers import AutoProcessor, AutoModelForCausalLM
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import requests
import torch
import io
import os

MODEL_ID = os.environ.get("MODEL_ID", "microsoft/Florence-2-base")
# Pinned so the downloaded weights *and* the remote modeling code
# (trust_remote_code) cannot change underneath us.
MODEL_REVISION = os.environ.get("MODEL_REVISION", "5ca5edf5bd017b9919c05d08aebef5e4c7ac3bac")
TASK = os.environ.get("TASK", "<MORE_DETAILED_CAPTION>")  # or "<CAPTION>" / "<DETAILED_CAPTION>"
HOST = os.environ.get("HOST", "localhost")
PORT = int(os.environ.get("PORT", "3001"))
MAX_UPLOAD_BYTES = int(os.environ.get("MAX_UPLOAD_BYTES", str(100 * 1024 * 1024)))


def load_model():
    print(f"Loading {MODEL_ID}@{MODEL_REVISION}...", flush=True)
    processor = AutoProcessor.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, trust_remote_code=True
    )
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
        trust_remote_code=True,
        torch_dtype=torch.float32,
        attn_implementation="eager",
    ).eval()
    print("Model loaded.", flush=True)
    return processor, model


def describe(processor, model, image: Image.Image) -> str:
    inputs = processor(text=TASK, images=image, return_tensors="pt")
    with torch.no_grad():
        generated_ids = model.generate(
            input_ids=inputs["input_ids"],
            pixel_values=inputs["pixel_values"],
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
        # GET /?file_path=<url>  - downloads the image from <url> (original API)
        def do_GET(self):
            parsed_url = urlparse(self.path)
            if parsed_url.path == "/up":
                return self.respond(200, "ok")

            file_path = parse_qs(parsed_url.query).get("file_path", [None])[0]
            if not file_path:
                return self.respond(400, "Missing 'file_path' parameter")

            try:
                content = requests.get(file_path, timeout=30).content
            except (
                requests.exceptions.MissingSchema,
                requests.exceptions.ConnectionError,
                requests.exceptions.Timeout,
            ):
                return self.respond(400, "Invalid image file")
            self.describe_bytes(content)

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
            except UnidentifiedImageError:
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
