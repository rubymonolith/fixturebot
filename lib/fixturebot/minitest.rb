# frozen_string_literal: true

require "fixturebot/rails"
require "fixturebot/syntax"

FixtureBot::Rails.compile

ActiveSupport::TestCase.include FixtureBot::Syntax::Methods
