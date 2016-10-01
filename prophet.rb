#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'mechanize'
require 'singleton'
require 'io/console'

class Game
  attr_accessor :favorite, :spread, :underdog, :total_points, :home_team
  attr_accessor :raw_favorite, :raw_underdog
  attr_accessor :confidence
end

class Record
  def points
    @win * 2 + @tie
  end

  attr_accessor :win, :loss, :tie
end

def get_team(name)
  case name.strip
    when /washington/i
      :Washington
    when /philadel?phia/i
      :Philadelphia
    when /dallas/i
      :Dallas
    when /((n\.?y\.?)|(new york)) giants/i
      :NyGiants
    when /detroit/i
      :Detroit
    when /green bay/i
      :GreenBay
    when /chicago/i
      :Chicago
    when /minnesota/i
      :Minnesota
    when /new orleans/i
      :NewOrleans
    when /tampa bay/i
      :TampaBay
    when /atlanta/i
      :Atlanta
    when /carolina/i
      :Carolina
    when /san francisco/i
      :SanFrancisco
    when /arizona/i
      :Arizona
    when /((l\.a\.)|(los angeles))/i
      :LosAngeles
    when /seattle/i
      :Seattle
    when /new england/i
      :NewEngland
    when /((n\.?y\.?)|(new york)) jets/i
      :NyJets
    when /buffalo/i
      :Buffalo
    when /miami/i
      :Miami
    when /cincinnati/i
      :Cincinnati
    when /baltimore/i
      :Baltimore
    when /cleveland/i
      :Cleveland
    when /pittsburgh/i
      :Pittsburgh
    when /houston/i
      :Houston
    when /jacksonville/i
      :Jacksonville
    when /tennessee/i
      :Tennessee
    when /indianapolis/i
      :Indianapolis
    when /oakland/i
      :Oakland
    when /san diego/i
      :SanDiego
    when /denver/i
      :Denver
    when /kansas city/i
      :KansasCity
    else
      raise "Unknown team: #{name}."
  end
end

def ryp_team_id(team)
  teams = [
    :Buffalo,
    :Indianapolis,
    :Miami,
    :NewEngland,
    :NyJets,
    :Cincinnati,
    :Cleveland,
    :Tennessee,
    :Pittsburgh,
    :Denver,
    :KansasCity,
    :Oakland,
    :SanDiego,
    :Seattle,
    :Dallas,
    :NyGiants,
    :Philadelphia,
    :Arizona,
    :Washington,
    :Chicago,
    :Detroit,
    :GreenBay,
    :Minnesota,
    :TampaBay,
    :Atlanta,
    :LosAngeles,
    :NewOrleans,
    :SanFrancisco,
    :Carolina,
    :Jacksonville,
    :Baltimore,
    :Houston
  ]
  teams.index(team) + 1
end

def make_game(values)
  game = Game.new
  game.raw_favorite = values[1].inner_text.strip.gsub /[\r\n]/, ' '
  game.favorite = get_team(game.raw_favorite.gsub /^At /, '')
  game.spread = values[2].inner_text.to_f
  game.raw_underdog = values[3].inner_text.strip.gsub /[\r\n]/, ' '
  game.underdog = get_team(game.raw_underdog.gsub /^At /, '')
  game.total_points = values[4] ? values[4].inner_text.to_f : 0
  game.home_team = (values[1].inner_text =~ /^At / ? game.favorite : game.underdog)
  return game
end

def make_record(values)
  record = Record.new
  record.win = values[1].inner_text.to_i
  record.loss = values[2].inner_text.to_i
  record.tie = values[3].inner_text.to_i
  return record
end

def game_sort(p, q, records)
  spread = p.spread <=> q.spread
  return spread if spread != 0

  return -1 if p.favorite == p.home_team
  return 1 if q.favorite == q.home_team

  p_record_spread = records[p.favorite].points - records[p.underdog].points
  q_record_spread = records[q.favorite].points - records[q.underdog].points

  record_spread = q_record_spread <=> p_record_spread
  return record_spread if record_spread != 0

  point_spread = records[q.favorite].points <=> records[p.favorite].points
  return point_spread if point_spread != 0

  return 0
end

lines_doc = Nokogiri::HTML(open('http://www.footballlocks.com/nfl_lines.shtml'))
records_doc = Nokogiri::HTML(open('http://www.nfl.com/standings'))

raw_records = records_doc.css('table.data-table1 tr.tbdy1')
records = {}
raw_records.each { |r|
  stats = r.css('td')
  team = get_team(stats[0].inner_text)
  records[team] = make_record(stats)
}

records.each { |t, r|
  puts "#{t}: #{r.win}-#{r.loss}-#{r.tie}"
}

puts

tables = lines_doc.css('table[cols="5"]')
tables = tables[tables.length - 2..tables.length]

raw_games = tables.map { |t| t.css('tr') }.flatten
raw_games = raw_games.find_all { |g| g.css('span').count <= 1 }.find_all { |g| g.css('td[width]').empty? }

games = []
raw_games.each { |g|
  values = g.css('td')
  game = make_game(values)
  games << game
}

games.sort! { |p, q|
  game_sort(p, q, records)
}

games.each { |game|
  fav = records[game.favorite]
  under = records[game.underdog]
  puts game.favorite if fav.nil?
  puts game.underdog if under.nil?
  puts "#{game.spread} #{game.raw_favorite} (#{fav.win}-#{fav.loss}-#{fav.tie}) > #{game.raw_underdog} (#{under.win}-#{under.loss}-#{under.tie})"
}

week = records.values.map { |r| r.win + r.loss + r.tie }.max + 1
puts "\nWeek: #{week}\n\n"

points = 16
games.each { |game|
  game.confidence = points
  points -= 1
}

games.each { |game|
  puts "%2d #{game.favorite}" % game.confidence
}

class Agent < ::Mechanize
  include Singleton

  def initialize
    super
    self.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

puts "\nEnter username and password to update picks.\n"

print 'Username: '
username = gets

print 'Password (hidden): '
password = $stdin.noecho { |stdin|
  stdin.gets
}

puts "\n\nUpdating picks..."

agent = Agent.instance

puts 'Logging in.'
homepage = agent.get('https://www.runyourpool.com')
homepage.form_with(action: /login_process/i) do |form|
  form['username'] = username
  form['password'] = password
  form.submit
end

# Maps team ID to the game ID they're playing in this week.
matches = {}

puts 'Getting pick sheet.'
picks_page = agent.get('http://www.runyourpool.com/nfl/confidence/picksheet_legacy.cfm?version=1')
picks_page.form_with(action: /picksheet_legacy_process/i) do |form|
  games.each do |g|
    team_id = ryp_team_id(g.favorite)
    input = form.radiobutton_with(value: team_id.to_s)

    game_id = input.name
    input.check

    form.field_with(type: nil, name: game_id.to_s).value = g.confidence
  end

  form['tiebreak'] = '42'
  form.submit
end

puts 'Getting pick review sheet.'
page = agent.get("http://www.runyourpool.com/nfl/confidence/print_picks.cfm?sheet_id=1&week=#{week}")
picks_file = File.join(Dir.mktmpdir, 'picks.html')

head = nil
page.search('//head').each do |e|
  e.children.first.add_previous_sibling('<base href="http://runyourpool.com">')
  head = e
end

File.open(picks_file, 'w+') do |file|
  file.write(head.document.to_s)
end

if Gem::Platform.local.os =~ /darwin/i
  system("open -a \"Google Chrome\" \"#{picks_file}\"")
else
  system("start chrome \"#{picks_file}\"")
end

puts 'Fin.'
