# frozen_string_literal: true

require_relative '../test_helper'

class CmsPageDebugTest < ActiveSupport::TestCase
  setup do
    @site   = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @page   = comfy_cms_pages(:default)
  end

  def test_simple_path_update_debug
    # Use the same setup as the working test
    page = comfy_cms_pages(:child)  # This is the existing child page
    page_a = @site.pages.create!(
      label: 'Test Page',
      slug: 'test-page-1',
      layout: @layout,
      parent: page
    )

    puts "Before update:"
    puts "Parent (child fixture) path: #{page.full_path}"
    puts "Child of child path: #{page_a.full_path}"

    # Update parent slug (this should trigger sync_child_full_paths!)
    page.update!(slug: 'updated-page')

    puts "After parent update (before reload):"
    puts "Parent path: #{page.full_path}"
    puts "Child path: #{page_a.full_path}"

    # Reload child to see if it was updated
    page_a.reload

    puts "After child reload:"
    puts "Parent path: #{page.full_path}"  
    puts "Child path: #{page_a.full_path}"

    assert_equal '/updated-page', page.full_path
    assert_equal '/updated-page/test-page-1', page_a.full_path
  end
end