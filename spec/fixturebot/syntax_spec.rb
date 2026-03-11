# frozen_string_literal: true

require "spec_helper"
require "fixturebot/syntax"

RSpec.describe FixtureBot::Syntax::Methods do
  let(:test_context) do
    Object.new.tap do |ctx|
      ctx.extend(FixtureBot::Syntax::Methods)

      # Stub fixture accessor: users(:brad), users(:alice)
      brad = double("brad",
        id: 1,
        attributes: { "id" => 1, "name" => "Brad", "email" => "brad@example.com", "created_at" => "2024-01-01", "updated_at" => "2024-01-01" },
        class: user_class
      )
      allow(brad).to receive(:dup).and_return(
        double("brad_dup",
          id: nil,
          new_record?: true,
          persisted?: false,
          class: user_class
        ).tap do |dup|
          allow(dup).to receive(:assign_attributes)
          allow(dup).to receive(:save!)
        end
      )

      alice = double("alice",
        id: 2,
        attributes: { "id" => 2, "name" => "Alice", "email" => "alice@example.com", "created_at" => "2024-01-01", "updated_at" => "2024-01-01" },
        class: user_class
      )
      allow(alice).to receive(:dup).and_return(
        double("alice_dup",
          id: nil,
          new_record?: true,
          persisted?: false,
          class: user_class
        ).tap do |dup|
          allow(dup).to receive(:assign_attributes)
          allow(dup).to receive(:save!)
        end
      )

      allow(ctx).to receive(:users).with(:brad).and_return(brad)
      allow(ctx).to receive(:users).with(:alice).and_return(alice)
    end
  end

  let(:user_class) do
    klass = double("User")
    allow(klass).to receive(:instantiate) do |attrs|
      double("stubbed_user", id: attrs["id"], persisted?: true, new_record?: false, **attrs.transform_keys(&:to_sym))
    end
    klass
  end

  describe "#build" do
    it "returns a dup of the fixture record" do
      result = test_context.build(:user, :brad)
      expect(result.new_record?).to be true
    end

    it "applies attribute overrides" do
      result = test_context.build(:user, :brad, name: "Changed")
      expect(result).to have_received(:assign_attributes).with(name: "Changed")
    end

    it "does not call assign_attributes when no overrides given" do
      result = test_context.build(:user, :brad)
      expect(result).not_to have_received(:assign_attributes)
    end
  end

  describe "#create" do
    it "returns the original fixture when no overrides given" do
      result = test_context.create(:user, :brad)
      expect(result.id).to eq(1)
    end

    it "builds and saves when overrides are given" do
      result = test_context.create(:user, :brad, name: "Changed")
      expect(result).to have_received(:assign_attributes).with(name: "Changed")
      expect(result).to have_received(:save!)
    end
  end

  describe "#build_stubbed" do
    it "retains the id from the fixture" do
      result = test_context.build_stubbed(:user, :brad)
      expect(result.id).to eq(1)
    end

    it "uses model class instantiate" do
      test_context.build_stubbed(:user, :brad)
      expect(user_class).to have_received(:instantiate)
    end

    it "merges attribute overrides" do
      result = test_context.build_stubbed(:user, :brad, name: "Stubbed")
      expect(result.name).to eq("Stubbed")
    end
  end

  describe "#attributes_for" do
    it "returns a hash without id, created_at, updated_at" do
      result = test_context.attributes_for(:user, :brad)
      expect(result).to eq({ name: "Brad", email: "brad@example.com" })
    end

    it "merges attribute overrides" do
      result = test_context.attributes_for(:user, :brad, name: "Override")
      expect(result[:name]).to eq("Override")
    end
  end

  describe "#build_list" do
    it "returns a record for each fixture name" do
      results = test_context.build_list(:user, :brad, :alice)
      expect(results.length).to eq(2)
      expect(results).to all(be_truthy)
    end
  end

  describe "#create_list" do
    it "returns a record for each fixture name" do
      results = test_context.create_list(:user, :brad, :alice)
      expect(results.length).to eq(2)
    end
  end

  describe "#build_pair" do
    it "returns two records" do
      results = test_context.build_pair(:user, :brad, :alice)
      expect(results.length).to eq(2)
    end
  end

  describe "#create_pair" do
    it "returns two records" do
      results = test_context.create_pair(:user, :brad, :alice)
      expect(results.length).to eq(2)
    end
  end

  describe "#build_stubbed_list" do
    it "returns stubbed records for each fixture name" do
      results = test_context.build_stubbed_list(:user, :brad, :alice)
      expect(results.length).to eq(2)
      expect(results.first.id).to eq(1)
      expect(results.last.id).to eq(2)
    end
  end

  describe "#build_stubbed_pair" do
    it "returns two stubbed records" do
      results = test_context.build_stubbed_pair(:user, :brad, :alice)
      expect(results.length).to eq(2)
    end
  end
end
