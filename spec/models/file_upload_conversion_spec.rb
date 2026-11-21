require 'rails_helper'

RSpec.describe FileUpload, 'conversion to a browser-friendly copy' do
  let(:heic) { create(:file_upload, fixture: 'upload.heic', content_type: 'image/heic') }
  let(:png) { create(:file_upload) }

  it 'creates a lossless PNG copy of a HEIC upload and keeps the original' do
    expect(heic.ensure_converted!).to be true

    copy = heic.converted.blob
    expect(copy.content_type).to eq 'image/png'
    expect(copy.filename.to_s).to eq 'upload.png'
    copy.analyze
    expect(copy.metadata.values_at('width', 'height')).to eq [320, 320]
    expect(heic.upload.blob.content_type).to eq 'image/heic' # original untouched
    expect(heic.display_blob).to eq copy
  end

  it 'leaves formats browsers can show alone' do
    expect(png.conversion).to be_nil
    expect(png.ensure_converted!).to be true
    expect(png.converted).not_to be_attached
    expect(png.display_blob).to eq png.upload.blob
  end

  it 'converts on demand when the file is served before the background job ran' do
    expect(heic.converted).not_to be_attached

    attachment = heic.display_attachment!

    expect(attachment.blob.content_type).to eq 'image/png'
  end

  it 'falls back to the original when the conversion fails' do
    allow(UploadConversion::ImageToPng).to receive(:call).and_raise(UploadConversion::Error, 'broken file')

    expect(heic.ensure_converted!).to be false
    expect(heic.display_attachment!.blob.content_type).to eq 'image/heic'
  end

  describe 'after upload' do
    it 'converts first and only then schedules the analysis' do
      expect { heic }.to have_enqueued_job(UploadConversionJob)
      expect { heic }.not_to have_enqueued_job(DescriptionFillingJob)

      expect { UploadConversionJob.perform_now(heic.id) }
        .to have_enqueued_job(DescriptionFillingJob)
        .and have_enqueued_job(FileUploadCaptionJob)
        .and have_enqueued_job(FileUploadEmbeddingJob)
      expect(heic.reload.converted).to be_attached
    end

    it 'schedules the analysis right away for other formats' do
      expect { png }.to have_enqueued_job(DescriptionFillingJob).and have_enqueued_job(FileUploadEmbeddingJob)
      expect { png }.not_to have_enqueued_job(UploadConversionJob)
    end
  end

  it 'runs OCR on the converted copy' do
    heic.ensure_converted!
    expect(RTesseract).to receive(:new).with(ActiveStorage::Blob.service.path_for(heic.converted.blob.key)).and_call_original

    FileUploadOcr.new(heic).text
  end
end
