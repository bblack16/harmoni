require 'bblib' unless defined?(BBLib::VERSION)
require 'json'
require 'yaml'

require_relative 'harmoni/version'
require_relative 'harmoni/config'
require_relative 'harmoni/types'

module Harmoni
  def self.build(path, *args, **opts)
    type = opts[:type] || Config.detect_type(path)
    Config.new(*args, opts.merge(type: type, path: path))
  end

  def self.sync(file, *args, **opts)
    build(file, *args, opts.merge(sync: true))
  end
end
