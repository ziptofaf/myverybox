# README

Simple and straightforward file sharing application, compatible with 
applications such as ShareX. 

## Running with Docker (recommended)

The whole stack is defined in `docker-compose.yml`:

- `web` - the Rails app (includes tesseract for OCR, ImageMagick and ffmpeg for previews)
- `clippy` - image description service ([Florence-2](https://huggingface.co/microsoft/Florence-2-base) on CPU, model baked into the image), see `clippy/`
- `db` - PostgreSQL

Uploaded files and the database are kept in the `storage` and `db` volumes.

1. `cp .env.example .env` and fill it in (`APP_HOSTNAME`, `SECRET_KEY_BASE`, `POSTGRES_PASSWORD`).
2. `docker compose up -d --build` (or set `WEB_IMAGE` / `CLIPPY_IMAGE` in `.env` to use the
   prebuilt images from GitHub Container Registry and run `docker compose pull && docker compose up -d`).
3. Create a user: `docker compose exec web bin/rails runner 'User.create!(email: "you@example.com", password: "yourpassword")'`
4. Optionally enable image descriptions under System settings.

The app listens on `127.0.0.1:3000` and expects a TLS-terminating reverse proxy (e.g. nginx) in front
of it. To try it locally over plain http, set `RAILS_FORCE_SSL=false` in `.env`.

Any value from `config/settings.yml` can be overridden with an environment variable prefixed with
`SETTINGS__`, e.g. `SETTINGS__HOSTNAME=https://myverybox.example.com`.

## Configuration (without Docker)

### Initial setup:

1. run `bundle install`
2. Create a new credentials file via `VISUAL="nano" rails credentials:edit`. You can just save changes and quit after file loads.
3. Create a file settings.local.yml in configuration directory (you can use settings.local.yml.example as a base).
4. Edit hostname so it matches your domain, eg. 'http://yourdomain.example.com'
5. You can also place it in config/settings/{environment.rb} if you have multiple environments
6. run `rails db:migrate`

###  Adding a new user:

    rails console
    user = User.create(password: 'yourpassword', password_confirmation: 'yourpassword', email: 'youremail@example.com')

### Configuring ShareX (or similar software)

1. Set a custom uploader
2. POST {http://yourdomain.example.com}/file_uploads/upload_via_api
3. Navigate to /api_keys on your instance of MyVeryBox, create a new one.
4. Add a header in ShareX - name is api_key, value is your API key value
5. Set url to {json:url} in response in ShareX, it will contain the path to newly uploaded file. 