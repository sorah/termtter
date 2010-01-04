# -*- coding: utf-8 -*-

URL_SHORTTERS = [
  { :host => "tinyurl.com", :pattern => %r'(http://tinyurl\.com(/[\w/]+))' },
  { :host => "is.gd", :pattern => %r'(http://is\.gd(/[\w/]+))' },
  { :host => "bit.ly", :pattern => %r'(http://bit\.ly(/[\w/]+))' },
  { :host => "ff.im", :pattern => %r'(http://ff\.im(/[-\w/]+))'},
  { :host => "j.mp", :pattern => %r'(http://j\.mp(/[\w/]+))' },
  { :host => "goo.gl", :pattern => %r'(http://goo\.gl(/[\w/]+))' },
]

config.plugins.expand_tinyurl.set_default(:shortters, [])
config.plugins.expand_tinyurl.set_default(:skip_users, [])

# for Ruby 1.8
unless String.public_method_defined?(:force_encoding)
  class String
    def force_encoding(enc)
      self
    end
  end

  module Encoding
    UTF_8 = nil
  end
end

Termtter::Client::register_hook(
  :name => :expand_tinyurl,
  :point => :filter_for_output,
  :exec_proc => lambda do |statuses, event|
    shortters = URL_SHORTTERS + config.plugins.expand_tinyurl.shortters
    skip_users = config.plugins.expand_tinyurl.skip_users
    statuses.each do |s|
      skip_users.include?(s.user.screen_name) and next
      shortters.each do |site|
        s.text.gsub!(site[:pattern]) do |m|
          expand_url(site[:host], $2) || $1
        end
      end
    end
    statuses
  end
)

def expand_url(host, path)
  res = Termtter::HTTPpool.start(host) do |h|
    h.get(path, { 'User-Agent' => 'Mozilla' })
  end
  return nil unless res.code == "301" or res.code == "302"
  res['Location'].force_encoding(Encoding::UTF_8)
rescue Exception => e
  Termtter::Client.handle_error(e)
  nil
end
