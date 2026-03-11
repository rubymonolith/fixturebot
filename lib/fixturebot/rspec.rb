# frozen_string_literal: true

require "fixturebot/rails"
require "fixturebot/syntax"

RSpec.configure do |config|
  config.before(:suite) do
    FixtureBot::Rails.compile
  end

  config.include FixtureBot::Syntax::Methods
end
