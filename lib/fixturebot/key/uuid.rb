# frozen_string_literal: true

require "digest/sha1"

module FixtureBot
  module Key
    module Uuid
      NAMESPACE = "fixturebot"

      module_function

      def generate(table_name, record_name)
        digest = Digest::SHA1.digest("#{NAMESPACE}:#{table_name}:#{record_name}")
        # Set version 5 (bits 4-7 of byte 6)
        digest[6] = ((digest[6].ord & 0x0f) | 0x50).chr
        # Set variant (bits 6-7 of byte 8)
        digest[8] = ((digest[8].ord & 0x3f) | 0x80).chr

        hex = digest[0, 16].unpack1("H*")
        "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
      end
    end
  end
end
