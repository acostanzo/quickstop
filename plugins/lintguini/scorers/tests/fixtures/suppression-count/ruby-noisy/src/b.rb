# frozen_string_literal: true

class B
  # rubocop:todo Lint/MissingSuper
  def initialize(x)
    @x = x
  end
  # rubocop:todo Lint/UselessAssignment
  def fetch
    y = @x
    @x
  end
  # rubocop:todo Metrics/MethodLength
  def long
    1
  end
  # rubocop:todo Metrics/AbcSize
  def complex
    @x + @x
  end
  # rubocop:todo Naming/AccessorMethodName
  def get_x
    @x
  end
  # rubocop:todo Style/StringLiterals
  def name
    "B"
  end
end
