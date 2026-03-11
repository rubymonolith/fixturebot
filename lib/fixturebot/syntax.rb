# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

module FixtureBot
  module Syntax
    module Methods
      def build(table_name, fixture_name, **attributes)
        record = send(table_name.to_s.pluralize, fixture_name).dup
        record.assign_attributes(attributes) if attributes.any?
        record
      end

      def create(table_name, fixture_name, **attributes)
        if attributes.any?
          build(table_name, fixture_name, **attributes).tap(&:save!)
        else
          send(table_name.to_s.pluralize, fixture_name)
        end
      end

      def build_stubbed(table_name, fixture_name, **attributes)
        source = send(table_name.to_s.pluralize, fixture_name)
        attrs = source.attributes
        attrs.merge!(attributes.stringify_keys) if attributes.any?
        source.class.instantiate(attrs)
      end

      def attributes_for(table_name, fixture_name, **attributes)
        send(table_name.to_s.pluralize, fixture_name)
          .attributes
          .symbolize_keys
          .except(:id, :created_at, :updated_at)
          .merge(attributes)
      end

      def build_list(table_name, *fixture_names, **attributes)
        fixture_names.map { |name| build(table_name, name, **attributes) }
      end

      def create_list(table_name, *fixture_names, **attributes)
        fixture_names.map { |name| create(table_name, name, **attributes) }
      end

      def build_pair(table_name, *fixture_names, **attributes)
        build_list(table_name, *fixture_names, **attributes)
      end

      def create_pair(table_name, *fixture_names, **attributes)
        create_list(table_name, *fixture_names, **attributes)
      end

      def build_stubbed_list(table_name, *fixture_names, **attributes)
        fixture_names.map { |name| build_stubbed(table_name, name, **attributes) }
      end

      def build_stubbed_pair(table_name, *fixture_names, **attributes)
        build_stubbed_list(table_name, *fixture_names, **attributes)
      end
    end
  end
end
