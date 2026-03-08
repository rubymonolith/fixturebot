# frozen_string_literal: true

require_relative "key/integer"
require_relative "key/uuid"

module FixtureBot
  module Key
    # Backward compatibility
    def self.generate(table_name, record_name)
      Integer.generate(table_name, record_name)
    end
  end
end
