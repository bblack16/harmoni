module Harmoni
  class Config
    include BBLib::Effortless
    include BBLib::TypeInit
    include BBLib::Delegator

    # The path to the file this will be stored in
    attr_str :path
    # If true changes made to the file will be automatically loaded via a watcher thread
    attr_bool :sync_up, default: false
    # If true changes made in memory (via set/delete) will be made to the file on disk
    attr_bool :sync_down, default: false
    # The configuration loaded from disk and from commands like set
    attr_hash :configuration, pre_proc: :process_config
    # Default configurations. @configuration gets precedence and merges over these.
    attr_hash :default_configuration, aliases: [:default, :defaults]
    # Overlayed configuration. Has precedence and gets overlayed over configuration.
    attr_hash :overlay_configuration, aliases: [:overlay]
    # If true, changes made in memory have precedence over changes made on disk when merging
    attr_bool :prefer_memory, default: false
    # If false changes made in memory are wiped out when reloading from disk.
    attr_bool :persist_memory, default: false
    # If true all keys in configuration (included nested ones) are converted to symbols when loaded
    attr_bool :keys_to_sym, default: true
    # Records the last time the file on disk was refreshed
    attr_time :last_refresh, serialize: false
    # How long to sleep after checking if the file has been modified
    attr_float_between 0.01, nil, :interval, default: 1
    # Hook that is called every time reload is invoked (due to changes to file)
    attr_of Proc, :on_reload, default: nil, allow_nil: true
    # Hook that is called any time reload is called and makes actual changes
    attr_of Proc, :on_change, default: nil, allow_nil: true
    # Register arbitrary events to matching keys or has path patterns
    attr_ary_of Event, :events, add_rem: true, adder_name: 'add_event', remover_name: 'remove_event'

    after :sync_up, :watch_file
    before :configuration=, :detect_changes, send_args: true

    delegate_to :configuration

    # Determines what type of config file should be used for a given file/path
    def self.detect_type(file)
      Config.descendants.find { |desc| desc.match?(file) }&.type || type
    end

    # Should be overriden in subclasses. This is used to determine whether
    # the file is the correct format for the class. For example, the yaml
    # class should use this to determine if the config file is yaml (if it exists)
    # or should be yaml (based on extension if it does not exist)
    def self.match?(file)
      false
    end

    # Set a single key value pair or merge in a hash. Keys can use hash path notation
    def set(key = nil, value = nil, **opts)
      if key
        detect_changes({ key => value }.expand)
        configuration.hpath_set(key => value)
      else
        detect_changes(opts.expand)
        opts.each do |k, v|
          configuration.hpath_set(k => v)
        end
      end
      save if sync_down
      true
    end

    alias []= set

    # Returns true if the sync thread is actively running and watching the file
    def watching?
      @watcher && @watcher.alive? ? true : false
    end

    # Get the first matching value for the key or path
    def get(key)
      get_all(key).first
    end

    alias [] get

    # Get all matching instancesof the key or path
    def get_all(key)
      configuration.hpath(key)
    end

    # Delete a key or nested path from the configuration
    def delete(key)
      configuration.hpath_delete.tap do |result|
        save if sync_down
      end
    end

    # Delete the entire config file (if one exists)
    def delete!
      return true unless File.exist?(path)
      FileUtils.rm(path)
    end

    # Clear our the configuration
    def clear
      self.configuration = {}
    end

    # Convenience wrapper for adding an event
    def on(key, &block)
      add_event(Event.new(key, &block))
    end

    # Turn on sync up and down in one call for convenience
    def sync(toggle)
      self.sync_up = toggle
      self.sync_down = toggle
    end

    alias sync= sync

    # Should persist the configuration to disk. This is adapter dependent
    def save
      # Nothing in base class. This should be used to persist settings in
      # subclasses that use files.
    end

    # Loads configuration from disk during synchronization
    def load_config
      # Nothing in base class. This should be used to load the configuration from
      # disk if saved to a file.
      {}
    end

    # Reload the configuration from disk and merge it in
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

    def to_tree_hash
      configuration.to_tree_hash
    end

    protected

    def simple_postinit(*args)
      named = BBLib.named_args(*args)
      sync(true) if named[:sync]
      reload
      watch_file if sync_up?
    end

    # Spin up a thread to monitor the file for changes
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

    # Determine what has changed after performing a reload to trigger the on_change hook.
    def detect_changes(hash)
      return unless (!events.empty? || on_change) && @configuration
      squished = hash.squish
      changes = configuration.squish.to_a.diff(squished.to_a).to_h.only(*squished.keys).expand
      return if changes.empty?
      on_change.call(hash, changes)
      trigger_events(changes)
    end

    def trigger_events(changes)
      events.each do |event|
        event.call(changes)
      end
    end

    # Processes configuration and converts it to a HashStruct internally
    def process_config(hash)
      return _compile(hash).to_hash_struct unless keys_to_sym?
      _compile(hash).keys_to_sym.to_hash_struct
    end

    # Applies defaults config, specified/loaded config and then overlay config
    def _compile(config)
      default_configuration.deep_merge(config).deep_merge(overlay_configuration)
    end

  end
end
