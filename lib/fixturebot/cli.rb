# frozen_string_literal: true

require "thor"

module FixtureBot
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "compile DIR", "Compile DIR/schema.rb and DIR/fixtures.rb to YAML fixture files"
    def compile(dir)
      fixture_set = load_fixture_set(dir)

      output_dir = File.join(dir, "fixtures")
      Compiler.new(fixture_set).compile(output_dir)

      say "Compiled fixtures to #{output_dir}/"
      fixture_set.tables.each do |table_name, records|
        next if records.empty?
        say "  #{table_name}.yml (#{records.size} records)"
      end
    end

    desc "show DIR", "Compile DIR/schema.rb and DIR/fixtures.rb, then print YAML to stdout"
    def show(dir)
      fixture_set = load_fixture_set(dir)
      compiler = Compiler.new(fixture_set)

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

    def load_fixture_set(dir)
      schema_path = File.join(dir, "schema.rb")
      fixtures_path = File.join(dir, "fixtures.rb")

      raise Thor::Error, "Schema file not found: #{schema_path}" unless File.exist?(schema_path)
      raise Thor::Error, "Fixtures file not found: #{fixtures_path}" unless File.exist?(fixtures_path)

      schema = eval(File.read(schema_path), binding, schema_path, 1)
      FixtureBot.define_from_file(schema, fixtures_path)
    end
  end
end
