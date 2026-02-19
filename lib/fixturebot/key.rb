# frozen_string_literal: true

require_relative "key/integer"
require_relative "key/uuid"

module FixtureBot
  module Key
    def self.resolve(value)
      case value
      when :integer then Integer.new
      when :uuid then UUID.new
      when Symbol
        raise ArgumentError,
          "unsupported primary key type: #{value.inspect} (must be :integer, :uuid, or a FixtureBot::Key object that responds to #generate)"
      else
        unless value.respond_to?(:generate)
          raise ArgumentError,
            "primary_key_type must be :integer, :uuid, or respond to #generate"
        end
        value
      end
    end
  end
end
