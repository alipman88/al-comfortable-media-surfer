# frozen_string_literal: true

require_relative '../test_helper'

class CmsPagePerformanceTest < ActiveSupport::TestCase
  setup do
    @site   = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @page   = comfy_cms_pages(:default)
  end

  def test_sync_child_full_paths_n_plus_one_issue
    # Create parent page
    parent = @site.pages.create!(
      label: 'Parent Page',
      slug: 'parent',
      layout: @layout,
      parent: @page
    )

    # Create many child pages to demonstrate N+1 issue
    child_pages = []
    10.times do |i|
      child = @site.pages.create!(
        label: "Child Page #{i}",
        slug: "child-#{i}",
        layout: @layout,
        parent: parent
      )
      child_pages << child
    end

    # Count SQL queries when updating parent slug
    queries_executed = count_queries do
      parent.update!(slug: 'new-parent')
    end

    # Verify the functionality still works correctly
    child_pages.each(&:reload)
    child_pages.each_with_index do |child, i|
      expected_path = "/new-parent/child-#{i}"
      assert_equal expected_path, child.full_path, 
        "Child path should be updated to #{expected_path}"
    end

    # Document the N+1 issue: with 10 children, we expect many individual UPDATE queries
    # Each child triggers its own save which can cause additional cascading updates
    puts "SQL queries executed for parent update with 10 children: #{queries_executed}"
    
    # This test documents the current N+1 behavior 
    # The current implementation uses individual update_attribute calls
    assert queries_executed >= 10, "Expected at least 10 queries (N+1 issue), got #{queries_executed}"
  end

  def test_benchmark_sync_child_full_paths_with_many_children
    # Create parent page
    parent = @site.pages.create!(
      label: 'Benchmark Parent',
      slug: 'benchmark-parent',
      layout: @layout,
      parent: @page
    )

    # Create many child pages to simulate production load
    25.times do |i|
      @site.pages.create!(
        label: "Benchmark Child #{i}",
        slug: "benchmark-child-#{i}",
        layout: @layout,
        parent: parent
      )
    end

    # Benchmark the save operation
    time_taken = Benchmark.realtime do
      parent.update!(slug: 'new-benchmark-parent')
    end

    puts "Time taken to update parent with 25 children: #{time_taken.round(4)} seconds"
    
    # This test documents current performance for future comparison
    assert time_taken >= 0, "Save operation should complete"
  end

  private

  def count_queries(&block)
    query_count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      # Skip schema queries and other non-data queries
      query_count += 1 unless payload[:name] == 'SCHEMA'
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
    query_count
  end
end