require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  let(:user) { create(:user) }

  describe 'creation' do
    it 'generates a token and stores only its digest' do
      key = user.api_keys.create!(description: 'ShareX')

      expect(key.token).to start_with('mvb_')
      expect(key.value_digest).to eq described_class.digest(key.token)
      expect(described_class.column_names).not_to include('value')
    end

    it 'does not expose the token once the key is loaded again' do
      key = user.api_keys.create!(description: 'ShareX')

      expect(described_class.find(key.id).token).to be_nil
    end

    it 'requires a description' do
      key = user.api_keys.new(description: '')

      expect(key).not_to be_valid
      expect(key.errors[:description]).to be_present
    end

    it 'sets the expiration from the chosen option' do
      freeze_time do
        expect(user.api_keys.create!(description: 'a', expires_in: '30').expires_at).to eq 30.days.from_now
        expect(user.api_keys.create!(description: 'b', expires_in: 'never').expires_at).to be_nil
        expect(user.api_keys.create!(description: 'c', expires_in: 'bogus').expires_at).to eq 90.days.from_now
      end
    end
  end

  describe '.authenticate' do
    let!(:key) { user.api_keys.create!(description: 'ShareX', expires_in: '30') }

    it 'finds the key by its plaintext token' do
      expect(described_class.authenticate(key.token)).to eq key
    end

    it 'rejects unknown and blank tokens' do
      expect(described_class.authenticate('mvb_nope')).to be_nil
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate('')).to be_nil
    end

    it 'rejects expired keys' do
      travel 31.days do
        expect(described_class.authenticate(key.token)).to be_nil
        expect(key.reload).to be_expired
      end
    end

    it 'rejects inactive keys' do
      key.update_column(:active, false)

      expect(described_class.authenticate(key.token)).to be_nil
    end
  end
end
