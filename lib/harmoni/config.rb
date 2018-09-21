module Harmoni
  class Config
    include BBLib::Effortless
    include BBLib::TypeInit
    include BBLib::Delegator

    attr_str :path
    attr_bool :sync_up, default: false
    attr_bool :sync_down, default: false
    attr_hash :configuration, pre_proc: :process_config
    attr_hash :default_configuration, aliases: [:default, :defaults]
    attr_hash :overlay_configuration, aliases: [:overlay]
    attr_bool :prefer_memory, default: false
    attr_bool :persist_memory, default: false
    attr_bool :keys_to_sym, default: true
    attr_time :last_refresh
    attr_float_between 0.01, nil, :interval, default: 1
    attr_of Proc, :on_reload, default: nil, allow_nil: true
    attr_of Proc, :on_change, default: nil, allow_nil: true

    after :sync_up, :watch_file
    before :configuration=, :detect_changes, send_args: true

    delegate_to :configuration

    def self.detect_type(file)
      descendants.find { |desc| desc.match?(file) }&.type || type
    end

    # Should be overriden in subclasses. This is used to determine whether
    # the file is the correct format for the class. For example, the yaml
    # class should use this to determine if the config file is yaml (if it exists)
    # or should be yaml (based on extension if it does not exist)
    def self.match?(file)
      false
    end

    def set(key = nil, value = nil, **opts)
      if key
        configuration.hpath_set(key => value)
      else
        opts.each do |k, v|
          configuration.hpath_set(k => v)
        end
      end
      save if sync_down
      true
    end

    alias []= set

    def watching?
      @watcher && @watcher.alive? ? true : false
    end

    def get(key)
      get_all(key).first
    end

    alias [] get

    def get_all(key)
      configuration.hpath(key)
    end

    def delete(key)
      configuration.hpath_delete.tap do |result|
        save if sync_down
      end
    end

    def sync(toggle)
      self.sync_up = toggle
      self.sync_down = toggle
    end

    alias sync= sync

    def save
      # Nothing in base class. This should be used to persist settings in
      # subclasses that use files.
    end

    def load_config
      # Nothing in base class. This should be used to load the configuration from
      # disk if saved to a file.
      {}
    end

    def reload
      if !persist_memory?
        self.configuration = load_config
      elsif prefer_memory
        self.configuration = load_config.deep_merge(configuration)
      else
        self.configuration = configuration.deep_merge(load_config)
      end
      self.last_refresh = Time.now
      on_reload.call(configuration) if on_reload
      true
    end

    protected

    def simple_postinit(*args)
      named = BBLib.named_args(*args)
      sync(true) if named[:sync]
      reload
      watch_file if sync_up?
    end

    def watch_file
      if sync_up? && (@watcher.nil? || !@watcher.alive?)
        BBLib.logger.debug("Spinning up a configuration watcher for #{path}")
        @watcher = Thread.new do
          loop do
            break unless sync_up?
            if path && File.exist?(path) && File.mtime(path) > last_refresh
              reload
            end
            sleep(interval)
          end
        end
      end
    end

    def detect_changes(hash)
      return unless on_change && @configuration
      changes = configuration.squish.to_a.diff(hash.squish.to_a).to_h.expand
      return if changes.empty?
      on_change.call(hash, changes)
    end

    def process_config(hash)
      return _compile(hash).to_hash_struct unless keys_to_sym?
      _compile(hash).keys_to_sym.to_hash_struct
    end

    def _compile(config)
      default_configuration.deep_merge(config).deep_merge(overlay_configuration)
    end

  end
end
