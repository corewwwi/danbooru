if Rails.env.development?
  Rack::MiniProfiler.config.position = 'right'
  Rack::MiniProfiler.config.disable_caching = true
end
