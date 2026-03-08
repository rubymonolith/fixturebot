# frozen_string_literal: true

require "fixturebot/rails"

RSpec.describe FixtureBot::Rails::SchemaLoader do
  before do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define(version: 2024_01_01_000000) do
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.string "email"
        t.timestamps
      end

      create_table "posts", force: :cascade do |t|
        t.string "title"
        t.text "body"
        t.integer "author_id"
        t.timestamps
      end

      add_foreign_key "posts", "users", column: "author_id"

      create_table "tags", force: :cascade do |t|
        t.string "name"
        t.timestamps
      end

      create_table "posts_tags", id: false, force: :cascade do |t|
        t.integer "post_id", null: false
        t.integer "tag_id", null: false
      end
    end
  end

  after do
    ActiveRecord::Base.connection_pool.disconnect!
  end

  subject(:schema) { described_class.load }

  it "loads regular tables with columns" do
    expect(schema.tables.keys).to contain_exactly(:users, :posts, :tags)
  end

  it "skips id, created_at, updated_at columns" do
    expect(schema.tables[:users].columns).to contain_exactly(:name, :email)
    expect(schema.tables[:posts].columns).to contain_exactly(:title, :body, :author_id)
    expect(schema.tables[:tags].columns).to contain_exactly(:name)
  end

  it "detects belongs_to associations from foreign keys" do
    associations = schema.tables[:posts].belongs_to_associations
    expect(associations.size).to eq(1)
    expect(associations.first.name).to eq(:author)
    expect(associations.first.table).to eq(:users)
    expect(associations.first.foreign_key).to eq(:author_id)
  end

  it "detects join tables" do
    expect(schema.join_tables.keys).to contain_exactly(:posts_tags)
    jt = schema.join_tables[:posts_tags]
    expect(jt.left_table).to eq(:posts)
    expect(jt.right_table).to eq(:tags)
    expect(jt.left_foreign_key).to eq(:post_id)
    expect(jt.right_foreign_key).to eq(:tag_id)
  end

  it "does not include join tables in regular tables" do
    expect(schema.tables).not_to have_key(:posts_tags)
  end

  it "detects default key strategy and primary key column" do
    table = schema.tables[:users]
    expect(table.key).to equal(FixtureBot::Key::Integer)
    expect(table.primary_key).to eq(:id)
  end

  context "with polymorphic associations" do
    before do
      ActiveRecord::Schema.define(version: 2024_01_02_000000) do
        create_table "votes", force: :cascade do |t|
          t.integer "votable_id"
          t.string "votable_type"
          t.integer "voter_id"
          t.timestamps
        end

        add_foreign_key "votes", "users", column: "voter_id"
      end
    end

    it "detects polymorphic associations from _id/_type pairs" do
      poly_assocs = schema.tables[:votes].polymorphic_associations
      expect(poly_assocs.size).to eq(1)
      expect(poly_assocs.first.name).to eq(:votable)
      expect(poly_assocs.first.foreign_key).to eq(:votable_id)
      expect(poly_assocs.first.foreign_type).to eq(:votable_type)
    end

    it "does not treat FK-constrained _id columns as polymorphic" do
      poly_names = schema.tables[:votes].polymorphic_associations.map(&:name)
      expect(poly_names).not_to include(:voter)
    end

    it "includes both FK-based and polymorphic associations" do
      assocs = schema.tables[:votes].associations
      expect(assocs.size).to eq(2)
      expect(assocs.map(&:name)).to contain_exactly(:voter, :votable)
    end
  end
end
