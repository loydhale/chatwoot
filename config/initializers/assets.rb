# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# NOTE: node_modules was previously added to the Sprockets asset load path
# (legacy from the Yarn/Webpacker era). Now that the dashboard uses Vite,
# node_modules is NOT needed by Sprockets. Including it caused Sprockets to
# scan 800+ MB of node_modules on first request, resulting in ~19-minute hangs
# in CI tests that render Administrate views.

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w[secretField.js]

# to take care of fonts in assets pre-compiling
# Ref: https://stackoverflow.com/questions/56960709/rails-font-cors-policy
# https://github.com/rails/sprockets/issues/632#issuecomment-551324428
Rails.application.config.assets.precompile << ['*.svg', '*.eot', '*.woff', '*.ttf']
