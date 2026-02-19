# frozen_string_literal: true

require "digest/sha1"

module FixtureBot
  module Key
    class UUID
      # RFC 4122 URL namespace UUID, used as the base namespace for UUID v5 generation.
      URL_NAMESPACE = "6ba7b811-9dad-11d1-80b4-00c04fd430c8"

      def generate(table_name, record_name)
        uuid_v5(URL_NAMESPACE, "fixturebot:#{table_name}:#{record_name}")
      end

      private

      def uuid_v5(namespace_uuid, name)
        namespace_bytes = [namespace_uuid.tr("-", "")].pack("H32")
        hash = Digest::SHA1.digest(namespace_bytes + name.to_s)

        bytes = hash.bytes[0, 16]
        bytes[6] = (bytes[6] & 0x0F) | 0x50 # Version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 # RFC 4122 variant

        hex = bytes.map { |b| "%02x" % b }.join
        "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
      end
    end
  end
end
