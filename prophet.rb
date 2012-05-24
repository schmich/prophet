require 'nokogiri'
require 'open-uri'

class Game
    attr_accessor :favorite, :spread, :underdog, :total_points, :home_team
    attr_accessor :raw_favorite, :raw_underdog
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
        when /philadelphia/i
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
        when /st\.? louis/i
            :StLouis
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

def make_game(values)
    game = Game.new
    game.raw_favorite = values[1].inner_text.strip.gsub /[\r\n]/, ' '
    game.favorite = get_team(game.raw_favorite.gsub /^At /, '')
    game.spread = values[2].inner_text.to_f
    game.raw_underdog = values[3].inner_text.strip.gsub /[\r\n]/, ' '
    game.underdog = get_team(game.raw_underdog.gsub /^At /, '')
    game.total_points = values[4].inner_text.to_f
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
records_doc = Nokogiri::HTML(open('http://espn.go.com/nfl/standings'))

raw_records = records_doc.css('div#my-teams-table table tr').find_all { |e| !/head/.match(e['class']) }

records = {}
raw_records.each { |r|
    stats = r.css('td')
    team = get_team(stats[0].inner_text.strip)

    records[team] = make_record(stats)
}

records.each { |t, r|
    puts "#{t}: #{r.win}-#{r.loss}-#{r.tie}"
}

puts

tables = lines_doc.css('table[cols="5"]')[0..1]
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
    frec = records[game.favorite]
    urec = records[game.underdog]
    puts game.favorite if frec.nil?
    puts game.underdog if urec.nil?
    puts "#{game.spread} #{game.raw_favorite} (#{frec.win}-#{frec.loss}-#{frec.tie}) > #{game.raw_underdog} (#{urec.win}-#{urec.loss}-#{urec.tie})"
}

puts

points = 16
games.each { |game|
    puts "%2d #{game.favorite}" % points
    points = points - 1
}

puts
system('pause')
