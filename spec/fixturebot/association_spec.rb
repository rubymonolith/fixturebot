# frozen_string_literal: true

RSpec.describe "Association resolve" do
  let(:keys) do
    # Simple stub that generates keys on the fly
    Object.new.tap do |obj|
      def obj.resolve(table_name, record_name)
        FixtureBot::Key::Integer.generate(table_name, record_name)
      end
    end
  end

  describe FixtureBot::Schema::BelongsTo do
    subject(:assoc) do
      FixtureBot::Schema::BelongsTo.new(name: :author, table: :users, foreign_key: :author_id)
    end

    it "resolves to a hash with the foreign key column" do
      result = assoc.resolve(:admin, keys)
      expected_id = FixtureBot::Key::Integer.generate(:users, :admin)
      expect(result).to eq({ author_id: expected_id })
    end
  end

  describe FixtureBot::Schema::PolymorphicBelongsTo do
    subject(:assoc) do
      FixtureBot::Schema::PolymorphicBelongsTo.new(
        name: :votable,
        foreign_key: :votable_id,
        foreign_type: :votable_type
      )
    end

    it "resolves to a hash with both id and type columns" do
      table_ref = FixtureBot::Row::TableReference.new(table_name: :posts, record_name: :hello)
      result = assoc.resolve(table_ref, keys)
      expected_id = FixtureBot::Key::Integer.generate(:posts, :hello)
      expect(result).to eq({ votable_id: expected_id, votable_type: "Post" })
    end

    it "classifies table names correctly" do
      table_ref = FixtureBot::Row::TableReference.new(table_name: :blog_posts, record_name: :hello)
      result = assoc.resolve(table_ref, keys)
      expect(result[:votable_type]).to eq("BlogPost")
    end
  end
end
