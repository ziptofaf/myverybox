# README

Simple and straightforward file sharing application, compatible with 
applications such as ShareX. 

## Configuration

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