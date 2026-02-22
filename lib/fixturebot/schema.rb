# frozen_string_literal: true

module FixtureBot
  class Schema
    Table = Data.define(:name, :singular_name, :columns, :belongs_to_associations, :polymorphic_belongs_to_associations)
    BelongsTo = Data.define(:name, :table, :foreign_key)
    PolymorphicBelongsTo = Data.define(:name, :foreign_key, :type_column)
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

      def table(name, singular:, columns: [], &block)
        associations = []
        polymorphic_associations = []
        if block
          table_builder = TableBuilder.new(associations, polymorphic_associations, columns)
          table_builder.instance_eval(&block)
        end

        columns_set = columns.to_set
        columns_set.grep(/_id$/).each do |id_col|
          type_col = id_col.to_s.sub(/_id$/, "_type").to_sym
          if columns_set.include?(type_col)
            assoc_name = id_col.to_s.sub(/_id$/, "").to_sym
            next if associations.any? { |a| a.name == assoc_name }
            next if polymorphic_associations.any? { |a| a.name == assoc_name }
            polymorphic_associations << PolymorphicBelongsTo.new(
              name: assoc_name,
              foreign_key: id_col,
              type_column: type_col
            )
          end
        end

        @schema.add_table(Table.new(
          name: name,
          singular_name: singular,
          columns: columns,
          belongs_to_associations: associations,
          polymorphic_belongs_to_associations: polymorphic_associations
        ))
      end

      def join_table(name, left_table, right_table)
        left_singular = @schema.tables[left_table].singular_name
        right_singular = @schema.tables[right_table].singular_name
        @schema.add_join_table(JoinTable.new(
          name: name,
          left_table: left_table,
          right_table: right_table,
          left_foreign_key: :"#{left_singular}_id",
          right_foreign_key: :"#{right_singular}_id"
        ))
      end
    end

    class TableBuilder
      def initialize(associations, polymorphic_associations, columns)
        @associations = associations
        @polymorphic_associations = polymorphic_associations
        @columns = columns
      end

      def belongs_to(name, table: nil)
        foreign_key = :"#{name}_id"
        type_column = :"#{name}_type"

        if table
          @associations << BelongsTo.new(name: name, table: table, foreign_key: foreign_key)
        elsif @columns.include?(foreign_key) && @columns.include?(type_column)
          @polymorphic_associations << PolymorphicBelongsTo.new(
            name: name,
            foreign_key: foreign_key,
            type_column: type_column
          )
        else
          raise ArgumentError, "belongs_to :#{name} requires table: option"
        end
      end
    end
  end
end
