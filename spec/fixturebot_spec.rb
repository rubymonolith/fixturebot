# frozen_string_literal: true

RSpec.describe FixtureBot do
  it "has a version number" do
    expect(FixtureBot::VERSION).not_to be nil
  end

  describe ".define" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
        table :posts, singular: :post, columns: [:title, :body, :author_id] do
          belongs_to :author, table: :users
        end
        table :tags, singular: :tag, columns: [:name]
        join_table :posts_tags, :posts, :tags
      end
    end

    let(:result) do
      FixtureBot.define(schema) do
        user.email { |fixture| "#{fixture.key}@blog.test" }

        user :admin do
          name "Brad"
          email "brad@blog.test"
        end

        user :reader do
          name "Alice"
        end

        post :hello_world do
          title "Hello world"
          body "Welcome to my blog."
          author :admin
          tags :ruby, :rails
        end

        tag :ruby do
          name "ruby"
        end

        tag :rails do
          name "rails"
        end
      end
    end

    it "produces the expected users" do
      users = result.tables[:users]

      expect(users[:admin][:name]).to eq("Brad")
      expect(users[:admin][:email]).to eq("brad@blog.test")

      expect(users[:reader][:name]).to eq("Alice")
      expect(users[:reader][:email]).to eq("reader@blog.test")
    end

    it "produces the expected posts with belongs_to" do
      posts = result.tables[:posts]
      admin_id = result.tables[:users][:admin][:id]

      expect(posts[:hello_world][:title]).to eq("Hello world")
      expect(posts[:hello_world][:body]).to eq("Welcome to my blog.")
      expect(posts[:hello_world][:author_id]).to eq(admin_id)
    end

    it "produces the expected tags" do
      tags = result.tables[:tags]
      expect(tags[:ruby][:name]).to eq("ruby")
      expect(tags[:rails][:name]).to eq("rails")
    end

    it "produces HABTM join table rows" do
      join = result.tables[:posts_tags]
      post_id = result.tables[:posts][:hello_world][:id]
      ruby_id = result.tables[:tags][:ruby][:id]
      rails_id = result.tables[:tags][:rails][:id]

      expect(join[:hello_world_ruby]).to eq({ post_id: post_id, tag_id: ruby_id })
      expect(join[:hello_world_rails]).to eq({ post_id: post_id, tag_id: rails_id })
    end
  end

  describe FixtureBot::Key do
    it "generates deterministic IDs" do
      id1 = FixtureBot::Key.generate(:users, :admin)
      id2 = FixtureBot::Key.generate(:users, :admin)
      expect(id1).to eq(id2)
    end

    it "generates positive integers" do
      id = FixtureBot::Key.generate(:users, :admin)
      expect(id).to be > 0
    end

    it "generates different IDs for different records" do
      id1 = FixtureBot::Key.generate(:users, :admin)
      id2 = FixtureBot::Key.generate(:users, :reader)
      expect(id1).not_to eq(id2)
    end
  end

  describe FixtureBot::Key, ".generate_uuid" do
    it "generates deterministic UUIDs" do
      uuid1 = FixtureBot::Key.generate_uuid(:users, :admin)
      uuid2 = FixtureBot::Key.generate_uuid(:users, :admin)
      expect(uuid1).to eq(uuid2)
    end

    it "generates valid UUID v5 format" do
      uuid = FixtureBot::Key.generate_uuid(:users, :admin)
      expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    it "generates different UUIDs for different records" do
      uuid1 = FixtureBot::Key.generate_uuid(:users, :admin)
      uuid2 = FixtureBot::Key.generate_uuid(:users, :reader)
      expect(uuid1).not_to eq(uuid2)
    end

    it "generates different UUIDs for same name in different tables" do
      uuid1 = FixtureBot::Key.generate_uuid(:users, :admin)
      uuid2 = FixtureBot::Key.generate_uuid(:posts, :admin)
      expect(uuid1).not_to eq(uuid2)
    end
  end

  describe "UUID primary key support" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email], primary_key_type: :uuid
        table :posts, singular: :post, columns: [:title, :author_id], primary_key_type: :uuid do
          belongs_to :author, table: :users
        end
        table :tags, singular: :tag, columns: [:name], primary_key_type: :uuid
        join_table :posts_tags, :posts, :tags
      end
    end

    let(:result) do
      FixtureBot.define(schema) do
        user :admin do
          name "Brad"
          email "brad@blog.test"
        end

        post :hello_world do
          title "Hello world"
          author :admin
          tags :ruby
        end

        tag :ruby do
          name "ruby"
        end
      end
    end

    it "generates UUID primary keys" do
      uuid = result.tables[:users][:admin][:id]
      expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    it "generates UUID foreign keys for belongs_to" do
      admin_uuid = result.tables[:users][:admin][:id]
      post_author_id = result.tables[:posts][:hello_world][:author_id]
      expect(post_author_id).to eq(admin_uuid)
    end

    it "generates UUID foreign keys in join tables" do
      post_uuid = result.tables[:posts][:hello_world][:id]
      tag_uuid = result.tables[:tags][:ruby][:id]
      join = result.tables[:posts_tags][:hello_world_ruby]

      expect(join[:post_id]).to eq(post_uuid)
      expect(join[:tag_id]).to eq(tag_uuid)
    end
  end

  describe "mixed integer and UUID primary keys" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :tenants, singular: :tenant, columns: [:name], primary_key_type: :uuid
        table :posts, singular: :post, columns: [:title, :tenant_id] do
          belongs_to :tenant, table: :tenants
        end
      end
    end

    let(:result) do
      FixtureBot.define(schema) do
        tenant :acme do
          name "Acme Corp"
        end

        post :hello do
          title "Hello"
          tenant :acme
        end
      end
    end

    it "generates integer ID for integer table" do
      post_id = result.tables[:posts][:hello][:id]
      expect(post_id).to be_a(Integer)
    end

    it "generates UUID for UUID table" do
      tenant_id = result.tables[:tenants][:acme][:id]
      expect(tenant_id).to match(/\A[0-9a-f]{8}-/)
    end

    it "uses UUID when referencing a UUID table from an integer table" do
      tenant_uuid = result.tables[:tenants][:acme][:id]
      post_tenant_id = result.tables[:posts][:hello][:tenant_id]
      expect(post_tenant_id).to eq(tenant_uuid)
    end
  end

  describe "generators" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
      end
    end

    it "accesses column values as methods" do
      result = FixtureBot.define(schema) do
        user.email { "#{name.downcase}@blog.test" }

        user :admin do
          name "Brad"
        end
      end

      expect(result.tables[:users][:admin][:email]).to eq("brad@blog.test")
    end

    it "preserves explicit nil over generator" do
      result = FixtureBot.define(schema) do
        user.email { |fixture| "#{fixture.key}@blog.test" }

        user :admin do
          name "Brad"
          email nil
        end
      end

      expect(result.tables[:users][:admin][:email]).to be_nil
    end

    it "receives a fixture object as block parameter" do
      result = FixtureBot.define(schema) do
        user.email { |fixture| "#{fixture.key}@blog.test" }

        user :alice
      end

      expect(result.tables[:users][:alice][:email]).to eq("alice@blog.test")
    end

  end

  describe "unknown method errors" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
      end
    end

    it "raises NoMethodError for unknown table methods" do
      expect {
        FixtureBot.define(schema) do
          widget :foo
        end
      }.to raise_error(NoMethodError)
    end

    it "raises NoMethodError for unknown column in row DSL" do
      expect {
        FixtureBot.define(schema) do
          user :admin do
            unknown_column "value"
          end
        end
      }.to raise_error(NoMethodError)
    end

    it "raises NoMethodError for unknown column on generator proxy" do
      expect {
        FixtureBot.define(schema) do
          user.nonexistent { "value" }
        end
      }.to raise_error(NoMethodError)
    end
  end

  describe "primary_key_type validation" do
    it "raises ArgumentError for unsupported primary_key_type" do
      expect {
        FixtureBot::Schema.define do
          table :users, singular: :user, columns: [:name], primary_key_type: :bigint
        end
      }.to raise_error(ArgumentError, /unsupported primary_key_type: :bigint/)
    end
  end
end
