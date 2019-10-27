module Harmoni
  module SettingsModule

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def settings
        @settings ||= load_settings
      end

      def load_settings
        map = config_settings.merge(
          default_configuration: default_settings,
          overlay_configuration: overlay_settings
        )
        Harmoni.build(send(:settings_path), map)
      end

      def default_settings
        const_defined?('DEFAULT_SETTINGS') ? const_get('DEFAULT_SETTINGS') : {}
      end

      def overlay_settings
        const_defined?('OVERLAY_SETTINGS') ? const_get('OVERLAY_SETTINGS') : {}
      end

      def config_settings
        const_defined?('CONFIG_SETTINGS') ? const_get('CONFIG_SETTINGS') : {}
      end

      def method_missing(method, *args, &block)
        settings.send(method, *args, &block)
      rescue NoMethodError => e
        super
      end
    end
  end
end
