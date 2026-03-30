# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("node_modules")

# (msw) Load darkmode seperately so we can prevent flashing the user with a
# bright screen onload
Rails.application.config.assets.precompile += %w(dark.js admin.js)

Rails.application.config.assets.css_compressor = nil
