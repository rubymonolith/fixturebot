# frozen_string_literal: true

require "thor"

module FixtureBot
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "compile DIR", "Compile DIR/schema.rb and DIR/fixtures.rb (or DIR/fixtures/*.rb) to YAML fixture files"
    def compile(dir)
      schema_path = File.join(dir, "schema.rb")
      raise Thor::Error, "Schema file not found: #{schema_path}" unless File.exist?(schema_path)

      paths = detect_fixture_files(dir)
      raise Thor::Error, "No fixture files found in: #{dir}" if paths.empty?

      schema = eval(File.read(schema_path), binding, schema_path, 1)
      fixture_set = FixtureBot.define_from_files(schema, *paths)

      output_dir = File.join(dir, "fixtures")
      Compiler.new(fixture_set).compile(output_dir)

      say "Compiled fixtures to #{output_dir}/"
      fixture_set.tables.each do |table_name, records|
        next if records.empty?
        say "  #{table_name}.yml (#{records.size} records)"
      end
    end

    desc "show DIR", "Compile DIR/schema.rb and DIR/fixtures.rb (or DIR/fixtures/*.rb), then print YAML to stdout"
    def show(dir)
      schema_path = File.join(dir, "schema.rb")
      raise Thor::Error, "Schema file not found: #{schema_path}" unless File.exist?(schema_path)

      paths = detect_fixture_files(dir)
      raise Thor::Error, "No fixture files found in: #{dir}" if paths.empty?

      schema = eval(File.read(schema_path), binding, schema_path, 1)
      fixture_set = FixtureBot.define_from_files(schema, *paths)
      compiler = FixtureBot::Compiler.new(fixture_set)

      fixture_set.tables.each do |table_name, records|
        next if records.empty?
        puts "# #{table_name}.yml"
        puts compiler.compile_table(table_name)
      end
    end

    map %w[-v --version] => :version
    desc "version", "Show version"
    def version
      say "fixturebot #{FixtureBot::VERSION}"
    end

    private

    def detect_fixture_files(dir)
      single = File.join(dir, "fixtures.rb")
      glob = Dir.glob(File.join(dir, "fixtures", "*.rb")).sort

      files = []
      files << single if File.exist?(single)
      files.concat(glob)
      files
    end
  end
end
