module Harmoni
  class YAML < Config
    include BBLib::Effortless

    def self.match?(file)
      if File.exist?(file)
        begin
          ::YAML.load_file(file)
          true
        rescue => _e
          false
        end
      else
        file.file_name =~ /\.(yml|yaml)$/i
      end
    end

    def save
      configuration.to_h.to_yaml.to_file(path, mode: 'w')
    end

    def load_config
      if File.exist?(path)
        ::YAML.load_file(path)
      else
        {}
      end
    rescue => e
      BBLib.logger.warn("Failed to load file as yaml @ #{path}: #{e}")
      {}
    end

  end
end
