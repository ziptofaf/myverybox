require 'rails_helper'

RSpec.describe ListNavigationHelper, type: :helper do
  describe '#page_window' do
    it 'shows every page when there are only a few' do
      expect(helper.page_window(1, 1)).to eq [1]
      expect(helper.page_window(3, 5)).to eq [1, 2, 3, 4, 5]
    end

    it 'shows first, last and a window around the current page with gaps' do
      expect(helper.page_window(1, 597)).to eq [1, 2, 3, nil, 597]
      expect(helper.page_window(50, 597)).to eq [1, nil, 48, 49, 50, 51, 52, nil, 597]
      expect(helper.page_window(597, 597)).to eq [1, nil, 595, 596, 597]
    end

    it 'shows a single skipped page instead of an ellipsis' do
      expect(helper.page_window(5, 10)).to eq [1, 2, 3, 4, 5, 6, 7, nil, 10]
    end
  end
end
