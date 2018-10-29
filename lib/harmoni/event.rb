module Harmoni
  class Event
    include BBLib::Effortless

    attr_of [String, Symbol, Regexp], :pattern, required: true, arg_at: 0
    attr_of Proc, :processor, required: true, arg_at: :block
    attr_bool :singular, default: true

    def call(changes)
      return false unless changes.is_a?(Hash)
      match = changes.hpath(pattern)
      return false if match.empty?
      match = match.first if singular?
      processor.call(match, pattern)
      true
    end

  end
end
