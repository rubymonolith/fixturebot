# frozen_string_literal: true

module FixtureBot
  module Default
    class Definition
      def initialize(table, defaults)
        @defaults = defaults
        define_column_methods(table)
      end

      private

      def define_column_methods(table)
        table.columns.each do |col|
          define_singleton_method(col) do |&block|
            raise ArgumentError, "#{col} requires a block" unless block
            @defaults[col] = Generator.new(block)
          end
        end
      end
    end

    Fixture = Data.define(:key)

    class Generator
      def initialize(block)
        @block = block
      end

      def generate(record_name, literal_values)
        context = Context.new(literal_values)
        context.instance_exec(Fixture.new(key: record_name), &@block)
      end

      private

      Context = Struct.new(:literal_values) do
        private

        def method_missing(name, *)
          if literal_values.key?(name)
            literal_values[name]
          else
            super
          end
        end

        def respond_to_missing?(name, *)
          literal_values.key?(name) || super
        end
      end
    end
  end
end
