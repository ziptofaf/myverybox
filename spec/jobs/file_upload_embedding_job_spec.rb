require 'rails_helper'

RSpec.describe FileUploadEmbeddingJob do
  let(:upload) { create(:file_upload) }
  let(:client) { instance_double(ImageEmbeddingClient) }

  before do
    allow(ImageEmbeddingClient).to receive(:new).and_return(client)
  end

  def analysis_enabled(value)
    Setting.find_or_initialize_by(name: 'image_description_analysis').update!(value_type: 'bool', value: value)
  end

  it 'stores the embedding and the model that produced it' do
    analysis_enabled('1')
    allow(client).to receive(:for_blob).and_return(
      ImageEmbeddingClient::Result.new(model: 'google/siglip2-base-patch16-256', embedding: Array.new(768, 0.5))
    )

    described_class.perform_now(upload.id)

    upload.reload
    expect(upload.embedding.size).to eq 768
    expect(upload.embedding_model).to eq 'google/siglip2-base-patch16-256'
  end

  it 'does nothing when image analysis is disabled' do
    analysis_enabled('0')
    expect(client).not_to receive(:for_blob)

    described_class.perform_now(upload.id)

    expect(upload.reload.embedding).to be_nil
  end

  it 'is scheduled after an upload is created' do
    expect { create(:file_upload) }.to have_enqueued_job(described_class)
  end
end
