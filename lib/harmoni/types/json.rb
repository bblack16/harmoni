module Harmoni
  class JSON < Config
    include BBLib::Effortless

    def self.match?(file)
      if File.exist?(file)
        begin
          ::JSON.parse(File.read(file))
          true
        rescue => _e
          false
        end
      else
        file.file_name =~ /\.json$/i
      end
    end

    def save
      configuration.to_json.to_file(path, mode: 'w')
    end

    def load_config
      if File.exist?(path)
        ::JSON.parse(File.read(path))
      else
        {}
      end
    rescue => e
      BBLib.logger.warn("Failed to load file as json @ #{path}: #{e}")
      {}
    end

  end
end
