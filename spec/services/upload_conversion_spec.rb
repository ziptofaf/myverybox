require 'rails_helper'

RSpec.describe UploadConversion do
  it 'converts browser-unfriendly image formats to PNG' do
    %w[image/heic image/heif image/tiff image/vnd.adobe.photoshop].each do |type|
      expect(described_class.for(type)&.to).to eq('image/png'), type
    end
  end

  it 'leaves formats browsers can show alone' do
    %w[image/png image/jpeg image/gif image/webp image/avif image/svg+xml video/mp4 application/pdf].each do |type|
      expect(described_class.for(type)).to be_nil, type
    end
  end

  it 'has well-formed rules' do
    described_class::RULES.each do |rule|
      expect(rule.from).to all(be_a(String))
      expect(rule.extension).to be_present
      expect(rule.converter).to respond_to(:call)
      expect([true, false]).to include(rule.on_demand)
    end
    sources = described_class::RULES.flat_map(&:from)
    expect(sources).to eq(sources.uniq) # one rule per format
  end
end
