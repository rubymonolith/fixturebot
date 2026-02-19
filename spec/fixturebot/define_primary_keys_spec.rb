# frozen_string_literal: true

RSpec.describe FixtureBot do
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
end
