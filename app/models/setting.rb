class Setting < ApplicationRecord 
  validates_inclusion_of :value_type, in: ['bool', 'number']
  validates_presence_of :value, :value_type, :name

  def formatted_value
    if value_type == 'bool'
      ActiveModel::Type::Boolean.new.cast(value)
    elsif value_type == 'number'
      value.to_i
    end
  end
end
