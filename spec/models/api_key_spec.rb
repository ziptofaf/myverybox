require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  describe 'creation' do
    let(:user) { create(:user) }

    it 'adds value automatically' do
      key = user.api_keys.create!
      expect(key.value).to_not be nil
    end
  end
end
