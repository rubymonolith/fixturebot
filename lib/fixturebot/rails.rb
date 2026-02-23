# frozen_string_literal: true

require "fixturebot"
require_relative "rails/schema_loader"
require_relative "rails/cli"
require_relative "rails/railtie" if defined?(::Rails::Railtie)

module FixtureBot
  module Rails
    def self.compile(fixtures_file: nil, output_dir: nil)
      files = resolve_fixtures_files(fixtures_file)
      return if files.empty?

      output_dir = resolve_output_dir(output_dir, files)

      schema = SchemaLoader.load
      fixture_set = FixtureBot.define_from_files(schema, *files)
      Compiler.new(fixture_set).compile(output_dir)
    end

    def self.resolve_fixtures_files(explicit)
      return Array(explicit).select { |f| File.exist?(f) } if explicit

      if defined?(::Rails::Railtie) && ::Rails.application&.config&.respond_to?(:fixturebot)
        configured = ::Rails.application.config.fixturebot.fixtures_file
        return Array(configured) if configured
      end

      detect_fixtures_files
    end
    private_class_method :resolve_fixtures_files

    def self.resolve_output_dir(explicit, files)
      return explicit if explicit

      if defined?(::Rails::Railtie) && ::Rails.application&.config&.respond_to?(:fixturebot)
        configured = ::Rails.application.config.fixturebot.output_dir
        return configured if configured
      end

      detect_output_dir(files)
    end
    private_class_method :resolve_output_dir

    def self.detect_fixtures_files
      %w[test spec].each do |dir|
        single = "#{dir}/fixtures.rb"
        glob = Dir.glob("#{dir}/fixtures/*.rb").sort

        if File.exist?(single) || glob.any?
          files = []
          files << single if File.exist?(single)
          files.concat(glob)
          return files
        end
      end

      []
    end
    private_class_method :detect_fixtures_files

    def self.detect_output_dir(files)
      first = files.first
      return "spec/fixtures" unless first

      # spec/fixtures.rb -> spec/fixtures
      # spec/fixtures/users.rb -> spec/fixtures
      # test/fixtures.rb -> test/fixtures
      if (m = first.match(%r{\A(test|spec)/fixtures(/|\.rb\z)}))
        "#{m[1]}/fixtures"
      else
        first.sub(/\.rb\z/, "")
      end
    end
    private_class_method :detect_output_dir
  end
end
