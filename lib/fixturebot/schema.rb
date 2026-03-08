# frozen_string_literal: true

module FixtureBot
  class Schema
    Table = Data.define(:name, :singular_name, :columns, :associations, :key, :primary_key) do
      def initialize(name:, singular_name:, columns:, associations: [], key: Key::Integer, primary_key: :id)
        super
      end

      def belongs_to_associations
        associations.reject(&:polymorphic?)
      end

      def polymorphic_associations
        associations.select(&:polymorphic?)
      end
    end

    BelongsTo = Data.define(:name, :table, :foreign_key) do
      def self.foreign_key(name) = :"#{name}_id"

      def polymorphic? = false

      def resolve(ref, keys)
        { foreign_key => keys.resolve(table, ref) }
      end
    end

    PolymorphicBelongsTo = Data.define(:name, :foreign_key, :foreign_type) do
      def self.foreign_key(name) = :"#{name}_id"
      def self.foreign_type(name) = :"#{name}_type"

      def polymorphic? = true

      def resolve(table_ref, keys)
        require "active_support/inflector" unless defined?(ActiveSupport::Inflector)

        {
          foreign_key => keys.resolve(table_ref.table_name, table_ref.record_name),
          foreign_type => ActiveSupport::Inflector.classify(table_ref.table_name.to_s)
        }
      end
    end

    JoinTable = Data.define(:name, :left_table, :right_table, :left_foreign_key, :right_foreign_key)

    attr_reader :tables, :join_tables

    def initialize
      @tables = {}
      @join_tables = {}
    end

    def add_table(table)
      @tables[table.name] = table
    end

    def add_join_table(join_table)
      @join_tables[join_table.name] = join_table
    end

    def self.define(&block)
      schema = new
      builder = Builder.new(schema)
      builder.instance_eval(&block)
      schema
    end

    class Builder
      def initialize(schema)
        @schema = schema
      end

      def table(name, singular:, columns: [], key: Key::Integer, primary_key: :id, &block)
        associations = []
        if block
          table_builder = TableBuilder.new(associations)
          table_builder.instance_eval(&block)
        end
        @schema.add_table(Table.new(
          name: name,
          singular_name: singular,
          columns: columns,
          associations: associations,
          key: key,
          primary_key: primary_key
        ))
      end

      def join_table(name, left_table, right_table)
        left_singular = @schema.tables[left_table].singular_name
        right_singular = @schema.tables[right_table].singular_name
        @schema.add_join_table(JoinTable.new(
          name: name,
          left_table: left_table,
          right_table: right_table,
          left_foreign_key: BelongsTo.foreign_key(left_singular),
          right_foreign_key: BelongsTo.foreign_key(right_singular)
        ))
      end
    end

    class TableBuilder
      def initialize(associations)
        @associations = associations
      end

      def belongs_to(name, table:)
        @associations << BelongsTo.new(name: name, table: table, foreign_key: BelongsTo.foreign_key(name))
      end

      def polymorphic(name)
        @associations << PolymorphicBelongsTo.new(
          name: name,
          foreign_key: PolymorphicBelongsTo.foreign_key(name),
          foreign_type: PolymorphicBelongsTo.foreign_type(name)
        )
      end
    end
  end
end
