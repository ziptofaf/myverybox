# Pagination and sortable column headers for the uploads list. Links keep the
# current search filters and sort order.
module ListNavigationHelper
  # Page numbers to show: first, last and a window around the current page,
  # with nil marking a gap, e.g. [1, nil, 4, 5, 6, 7, 8, nil, 597].
  def page_window(page, total_pages, radius: 2)
    pages = ([1, total_pages] + ((page - radius)..(page + radius)).to_a).select { |p| p.between?(1, total_pages) }.uniq.sort
    pages.each_with_object([]) do |p, out|
      if out.last && p - out.last > 2
        out << nil
      elsif out.last && p - out.last == 2
        out << p - 1 # a gap of exactly one page: show the page instead of "..."
      end
      out << p
    end
  end

  def pagination_nav(page:, total_pages:, total_count:, per_page:)
    first = total_count.zero? ? 0 : ((page - 1) * per_page) + 1
    last = [page * per_page, total_count].min
    summary = tag.div(class: 'list-summary') do
      total_count.zero? ? 'No files found' : "Showing #{first}–#{last} of #{number_with_delimiter(total_count)} files"
    end
    return summary if total_pages <= 1

    items = []
    items << page_item('‹ Previous', page - 1, disabled: page == 1, rel: 'prev')
    page_window(page, total_pages).each do |p|
      items << (p ? page_item(number_with_delimiter(p), p, active: p == page) : tag.div('…', class: 'disabled item'))
    end
    items << page_item('Next ›', page + 1, disabled: page == total_pages, rel: 'next')

    summary + tag.nav(safe_join(items), class: 'ui pagination menu', 'aria-label': 'Pages')
  end

  # Column header that sorts the list by `key`; clicking the active column flips the direction.
  def sort_header(label, key, default_direction: 'desc')
    return label if @sorted_by_relevance || @sort.nil?

    active = @sort == key
    direction = active ? (@direction == 'asc' ? 'desc' : 'asc') : default_direction
    arrow = active ? (@direction == 'asc' ? ' ▲' : ' ▼') : ''
    link_to "#{label}#{arrow}", list_params(sort: key, direction: direction, page: 1),
            class: ('active-sort' if active), title: "Sort by #{label.downcase}"
  end

  private

  def page_item(label, page, active: false, disabled: false, rel: nil)
    return tag.div(label, class: 'disabled item') if disabled

    link_to label, list_params(page: page), class: ['item', ('active' if active)].compact.join(' '),
            rel: rel, 'aria-current': ('page' if active)
  end

  def list_params(overrides)
    params.permit(:sort, :direction, :page, search: {}).merge(overrides)
  end
end
