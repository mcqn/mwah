#!/usr/bin/ruby

require 'rss'
require 'open-uri'
our_location = File.dirname(__FILE__)
require "#{our_location}/time_start_and_end_extensions.rb"
require 'yaml'

def get_recent_bookmarks(user, tag)
  tag_clause = tag.nil? ? nil : "t:#{tag}/"
  url = "http://feeds.pinboard.in/rss/u:#{user}/#{tag_clause}"
  items = nil
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    puts feed.channel.title
    puts feed.items.length
    items = feed.items
  end
  items
end

# Read in config
settings = nil
if ARGV.length == 1
  settings = YAML.load_file(ARGV[0])
else
  puts "No configuration provided."
  exit
end

combined = []
settings["accounts"].each do |u|
  puts u.inspect
  if u["tags"].nil?
    # Get all the bookmarks
    items = get_recent_bookmarks(u["user"], nil)
    combined += items
  else
    # Get the bookmarks for each of the given tags
    u["tags"].each do |t|
      items = get_recent_bookmarks(u["user"], t["tag"])
      combined += items
    end
  end
end

a_week_ago = Time.now.start_of_day - settings["num_days"].to_i.days
puts "Finding links after "+a_week_ago.to_s
combined.sort! { |a,b| a.dc_date <=> b.dc_date }
combined.reject! { |i| i.dc_date < a_week_ago }
unless settings["include_today"]
  puts "And before "+Time.now.start_of_day.to_s
  combined.reject! { |i| i.dc_date > Time.now.start_of_day }
end
combined.each do |c|
  puts c.dc_date.to_s + " " + c.title
end

# Now we have the links, create the blog post
unless combined.empty?
  post_filename = "#{Date.today.to_s}-Indie-Manufacturing-Links.html"
  post_title = "#{Date.today.to_s} Indie Manufacturing Links"
  all_tags = combined.collect { |l| l.dc_subject.split }
  all_tags = all_tags.flatten.uniq.sort
  File.open("#{settings["output_dir"]}/#{post_filename}", "w") do |post|
    post.puts "---"
    post.puts "layout: #{settings["layout"]}"
    post.puts "title: #{post_title}"
    post.puts "description: 'Links from pinboard'"
    post.puts "category: #{settings["category"]}" unless settings["category"].nil? || settings["category"] == ""
    post.puts "tag: [#{all_tags.join(",")}]"
    post.puts "---"
    post.puts settings["link_preamble"]
    post.puts "<ul>"
    combined.each do |l|
      post.puts "  <li>"
      post.puts "    <span class='pinboard-title'><a href='#{l.link}'>#{l.title}</a></span>"
      post.puts "    <meta name='dc_date' content='#{l.dc_date}' />"
      post.puts "    <meta name='dc_creator' content='#{l.dc_creator}' />"
      post.puts "    <meta name='dc_identifier' content='#{l.dc_identifier}' />"
      post.puts "    <span class='pinboard-description'>#{l.description}</span>"
      unless l.dc_subject.split.empty?
        post.puts "    <div class='pinboard-tags'>tags:"
        l.dc_subject.split.each do |tag|
          post.puts "      <span class='pinboard-tag'><a href='/tag/#{tag.downcase}/'>#{tag}</a></span>"
        end
        post.puts "    </div>"
      end
      post.puts "  </li>"
    end
    post.puts "</ul>"
  end
end
