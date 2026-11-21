class Setting < ApplicationRecord 
  validates_inclusion_of :value_type, in: ['bool', 'number']
  validates_presence_of :value, :value_type, :name

  IMAGE_ANALYSIS = 'image_description_analysis'.freeze

  # Image analysis (descriptions + search by image content) uses the clippy
  # service; when it's off, nothing is sent there and image search is hidden.
  def self.image_analysis_enabled?
    find_by(name: IMAGE_ANALYSIS)&.formatted_value == true
  end

  def formatted_value
    if value_type == 'bool'
      ActiveModel::Type::Boolean.new.cast(value)
    elsif value_type == 'number'
      value.to_i
    end
  end
end
