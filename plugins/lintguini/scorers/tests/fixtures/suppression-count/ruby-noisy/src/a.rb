# frozen_string_literal: true

class A
  def x; end # rubocop:disable Style/EmptyMethod
  def y; end # rubocop:disable Style/EmptyMethod
  def z; end # rubocop:disable Style/EmptyMethod
  # rubocop:disable Style/Documentation
  def aa; end
  def bb; end
  def cc; end
  # rubocop:enable Style/Documentation
end
