# frozen_string_literal: true

require_relative "fixturebot/version"
require_relative "fixturebot/schema"
require_relative "fixturebot/key"
require_relative "fixturebot/default"
require_relative "fixturebot/row"
require_relative "fixturebot/definition"
require_relative "fixturebot/key_registry"
require_relative "fixturebot/fixture_set"
require_relative "fixturebot/compiler"
require_relative "fixturebot/cli"

module FixtureBot
  class Error < StandardError; end

  # Programmatic API: FixtureBot.define(schema) { ... }
  # File API (no schema): FixtureBot.define { ... } — evaluated against current_definition if set
  def self.define(schema = nil, &block)
    if schema
      definition = Definition.new(schema)
      evaluate_block(definition, block)
      FixtureSet.new(schema, definition)
    elsif Thread.current[:fixturebot_definition]
      evaluate_block(Thread.current[:fixturebot_definition], block)
      nil
    else
      raise Error, "FixtureBot.define without a schema must be called from within define_from_file"
    end
  end

  def self.define_from_file(schema, fixtures_path)
    definition = Definition.new(schema)
    Thread.current[:fixturebot_definition] = definition
    eval(File.read(fixtures_path), TOPLEVEL_BINDING, fixtures_path, 1)
    FixtureSet.new(schema, definition)
  ensure
    Thread.current[:fixturebot_definition] = nil
  end

  def self.evaluate_block(definition, block)
    if block.arity > 0
      block.call(definition)
    else
      definition.instance_eval(&block)
    end
  end
  private_class_method :evaluate_block
end
