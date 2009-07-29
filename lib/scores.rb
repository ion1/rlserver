require "config"

module Scores
  COLORS = ["odd", "even"]

  class Score
  end
  
  class CrawlScores
    attr_reader :player_points, :bonus_points, :total_points, :bonus_mult, :data, :bonuses
    def initialize(filename)
      @data = []
      File.open(filename) do |file|
        file.read.each_line do |line|
          dataset = {}
          line.sub! /::/, "##"
          line.split(":").each do |pair|
            pair.sub! /##/, ":"
            key, value = pair.split("=")
            dataset[key] = value
          end
          @data << dataset
        end
      end
    end

    def calculate_bonus
      @player_points = {}
      @data.each do |dat|
        @player_points[dat["name"]] = @player_points[dat["name"]].to_i + dat["sc"].to_i
      end
      race = []
      cls  = []
      @bonus_points = {}
      @bonuses = {}
      @data.each do |dat|
        if not @bonuses.member?(dat["name"]) then @bonuses[dat["name"]] = [[],[]] end
        if not race.member? dat["race"]
          race << dat["race"]
          @bonus_points[dat["name"]] = @bonus_points[dat["name"]].to_i + 1
          @bonuses[dat["name"]][0] << dat["race"]
        end
        if not cls.member? dat["cls"]
          cls << dat["cls"]
          @bonus_points[dat["name"]] = @bonus_points[dat["name"]].to_i + 1
          @bonuses[dat["name"]][1] << dat["cls"]
        end
      end

      @bonus_mult = @player_points.values.inject{|x,y|x+y}/100.0
      @total_points = {}
      @player_points.each_pair do |key, val|
        @total_points[key] = @total_points[key].to_i + val
      end
      @bonus_points.each_pair do |key, val|
        @total_points[key] = @total_points[key].to_f + val * @bonus_mult
      end
    end
  end

  def self.updatecrawl
    score = CrawlScores.new(Config.config["games"]["crawl"]["scores"])
    score.calculate_bonus
    html = <<HTML_END
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
  <head>
    <title>Crawl Scores</title>
    <script type="text/javascript" src=".sortabletable/js/sortabletable.js"></script>
    <link rel="stylesheet" type="text/css" href=".sortabletable/css/sortabletable.css"/>
    <link rel="stylesheet" type="text/css" href=".style.css"/>
  </head>
  <body>
    <p>
    <table class="sort-table" id="scores">
      <thead><tr align="left"><th>#</th><th>Score</th><th>Name</th><th>Character</th><th>Place</th><th>Turns</th><th>Quit reason</th></tr></thead>
      <tbody>#{i=0;score.data.map{|points| "<tr class=#{COLORS[i % 2]}><td>#{i+=1}</td><td align=\"right\">#{points["sc"]}</td><td>#{points["name"]}</td><td>#{points["race"]} #{points["cls"]} (lvl: #{points["xl"]})</td><td>#{points["place"]}</td><td align=\"right\">#{points["turn"]}</td><td>#{points["tmsg"]}</td></tr>"}.join("\n")}</tbody>
    </table>
    </p>
  </body>
</html>
HTML_END
    File.open("crawl/scores.html" , "w") {|file| file.write(html)}
  end
end
