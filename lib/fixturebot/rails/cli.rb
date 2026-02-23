# frozen_string_literal: true

require "fixturebot/cli"

module FixtureBot
  module Rails
    class CLI < FixtureBot::CLI
      desc "compile FILES... [--output OUTPUT_DIR]", "Compile FixtureBot DSL to YAML fixture files"
      option :output, aliases: "-o", default: "test/fixtures", desc: "Output directory"
      def compile(*paths)
        raise Thor::Error, "No fixture files specified" if paths.empty?

        paths.each do |path|
          raise Thor::Error, "Fixtures file not found: #{path}" unless File.exist?(path)
        end

        schema = SchemaLoader.load
        fixture_set = FixtureBot.define_from_files(schema, *paths)
        output_dir = options[:output]
        Compiler.new(fixture_set).compile(output_dir)

        say "Compiled fixtures to #{output_dir}/"
        fixture_set.tables.each do |table_name, records|
          next if records.empty?
          say "  #{table_name}.yml (#{records.size} records)"
        end
      end
    end
  end
end
