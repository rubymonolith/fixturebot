# frozen_string_literal: true

require "zlib"

module FixtureBot
  module Key
    class Integer
      def generate(table_name, record_name)
        Zlib.crc32("#{table_name}:#{record_name}") & 0x7FFFFFFF
      end
    end
  end
end
