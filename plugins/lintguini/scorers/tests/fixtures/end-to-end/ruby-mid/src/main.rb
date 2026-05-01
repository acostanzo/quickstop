# frozen_string_literal: true

class Main
  def helper(x) # rubocop:disable Style/EmptyMethod
  end

  def double(x) # rubocop:todo Lint/UselessAssignment
    y = x
    x * 2
  end
end
