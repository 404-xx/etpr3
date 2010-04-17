# Be sure to restart your server when you modify this file.

# Rails.application.config.session_store :cookie_store, :key => '_etpr3_session'
Rails.application.config.session_store :cookie_store, {
  :key    => '_etpr3_session',
  :secret => '510d082812bf76c2bd7a3525da0b16ead3a6va4717691db901ddb4d32116faa4f073952d1e3ead1de25e6e807493ad21d9ca95fc44eec326cfea948d91a81df6'
}
# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# Rails.application.config.session_store :active_record_store
