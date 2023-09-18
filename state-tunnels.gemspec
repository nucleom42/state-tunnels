# frozen_string_literal: true

Gem::Specification.new do |s|
  s.author = ['Oleg Saltykov']
  s.homepage = 'https://github.com/nucleom42/state-tunnels'
  s.name = 'validy'
  s.version = '0.0.1'
  s.licenses = ['MIT']
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = 'StateTunnels - lightweight and simple Active Record enum switching validation'
  s.files = Dir['lib/*']
  s.require_paths = %w[lib]
end
