require 'rails_helper'

RSpec.describe ExpiredUploadsCleanUpJob, type: :job do
  let!(:expired) { create(:file_upload).tap { |f| f.update_columns(expires_after: 1.hour.ago) } }
  let!(:expires_later) { create(:file_upload).tap { |f| f.update_columns(expires_after: 1.day.from_now) } }
  let!(:never_expires) { create(:file_upload) }

  def removal_enabled(value)
    Setting.find_or_initialize_by(name: 'remove_expired_files').update!(value_type: 'bool', value: value)
  end

  it 'removes only expired uploads when enabled' do
    removal_enabled('1')

    expect(described_class.perform_now).to eq 1

    expect(FileUpload.exists?(expired.id)).to be false
    expect(FileUpload.where(id: [expires_later.id, never_expires.id]).count).to eq 2
  end

  it 'does nothing when disabled' do
    removal_enabled('0')

    expect { described_class.perform_now }.not_to(change { FileUpload.count })
  end

  it 'removes expired uploads when forced, even if disabled' do
    removal_enabled('0')

    described_class.perform_now(force: true)

    expect(FileUpload.exists?(expired.id)).to be false
  end

  describe 'schedule' do
    # parsed by Solid Queue itself, like its scheduler does in production
    let(:tasks) do
      YAML.load(ERB.new(Rails.root.join('config/recurring.yml').read).result).fetch('production')
          .to_h { |key, options| [key, SolidQueue::RecurringTask.from_configuration(key, **options.symbolize_keys)] }
    end

    it 'runs daily at 04:00 UTC in production' do
      task = tasks.fetch('clean_up_expired_uploads')

      expect(task).to be_valid
      expect(task.class_name.constantize).to eq described_class
      travel_to(Time.utc(2026, 1, 1, 12)) { expect(task.next_time).to eq Time.utc(2026, 1, 2, 4) }
    end

    it 'only contains valid tasks' do
      tasks.each_value { |task| expect(task).to be_valid, task.errors.full_messages.inspect }
    end
  end
end
